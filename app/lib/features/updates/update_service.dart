import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const updateManifestUrl = String.fromEnvironment('UPDATE_MANIFEST_URL');

/// iOS 的下载入口。iOS 无法应用内安装（只装签名包、自签还 7 天过期），
/// 所以「更新」退化成「发现新版 → 引导去这里下未签名 ipa」。
const iosReleasePageUrl = 'https://github.com/xinghe-labs/kuangshuati/releases';

/// 更新相关原生能力缺失时的统一错误文案。
const fallbackVersionCode = int.fromEnvironment(
  'APP_VERSION_CODE',
  defaultValue: 1,
);
const fallbackVersionName = String.fromEnvironment(
  'APP_VERSION_NAME',
  defaultValue: '1.0.0',
);

class AppVersion {
  const AppVersion({required this.name, required this.code});

  final String name;
  final int code;
}

class UpdateInfo {
  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.apkSha256,
    required this.apkSize,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String versionName;
  final int versionCode;
  final Uri apkUrl;
  final String apkSha256;
  final int apkSize;
  final List<String> releaseNotes;
  final bool mandatory;
}

/// 只知道「有没有新版本」，不含安装包信息。
///
/// iOS 装不了 APK，用不上 apkUrl/sha256/size；另开一个轻量结构，
/// 避免让 Android 的 [UpdateInfo] 出现一堆可空字段。
class AvailableVersion {
  const AvailableVersion({
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.mandatory,
  });

  final String versionName;
  final int versionCode;
  final List<String> releaseNotes;
  final bool mandatory;
}

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateService {
  UpdateService({
    this._channel = const MethodChannel('com.kuangshuati.app/updates'),
    this.manifestUrl = updateManifestUrl,
    Future<Directory> Function()? temporaryDirectory,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final MethodChannel _channel;
  final String manifestUrl;
  final Future<Directory> Function() _temporaryDirectory;

  Future<AppVersion> currentVersion() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getVersion',
      );
      return AppVersion(
        name: result?['versionName'] as String? ?? fallbackVersionName,
        code: (result?['versionCode'] as num?)?.toInt() ?? fallbackVersionCode,
      );
    } on MissingPluginException {
      return const AppVersion(
        name: fallbackVersionName,
        code: fallbackVersionCode,
      );
    }
  }

  Future<UpdateInfo?> checkForUpdate() async {
    final body = await _fetchManifest();
    final current = await currentVersion();
    return parseManifest(body, currentVersionCode: current.code);
  }

  /// 只查版本号。
  ///
  /// iOS 用这个：线上清单是 Android 渠道发的（`platform: android`、带
  /// apkUrl/sha256），iOS 装不了 APK，但「当前版本号 < 清单版本号」这件事
  /// 与平台无关，iOS 想知道的就这一点。
  Future<AvailableVersion?> checkForVersionOnly() async {
    final body = await _fetchManifest();
    final current = await currentVersion();
    return parseAvailableVersion(body, currentVersionCode: current.code);
  }

  /// 打开 iOS 的下载页（Releases 列表）。
  ///
  /// 只有 iOS 原生端实现了 `openUrl`；Android 走应用内安装用不到它，
  /// 桌面端没有这个通道。这两种情况返回 false，由调用方降级成复制链接。
  Future<bool> openReleasePage() async {
    try {
      return await _channel.invokeMethod<bool>(
            'openUrl',
            {'url': iosReleasePageUrl},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 拉取并返回清单原文。Android 与 iOS 共用，错误文案保持一致。
  Future<String> _fetchManifest() async {
    if (manifestUrl.trim().isEmpty) {
      throw const UpdateException('当前安装包尚未配置应用更新源');
    }
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.scheme != 'https') {
      throw const UpdateException('应用更新地址必须使用 HTTPS');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'Kuangshuati-Android-Updater/1';
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('更新服务器返回 HTTP ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join();
    } on TimeoutException {
      throw const UpdateException('检查更新超时，请稍后重试');
    } on SocketException {
      throw const UpdateException('无法连接更新服务器');
    } finally {
      client.close(force: true);
    }
  }

  static UpdateInfo? parseManifest(
    String source, {
    required int currentVersionCode,
  }) {
    final decoded = _decodeManifest(source);
    if (decoded['platform'] != 'android') {
      throw const UpdateException('更新清单平台不匹配');
    }
    final versionCode = _positiveInt(decoded['versionCode'], 'versionCode');
    if (versionCode <= currentVersionCode) return null;

    final versionName = decoded['versionName'];
    final apkUrlValue = decoded['apkUrl'];
    final sha = decoded['apkSha256'];
    final apkSize = _positiveInt(decoded['apkSize'], 'apkSize');
    if (versionName is! String || versionName.trim().isEmpty) {
      throw const UpdateException('更新清单缺少版本名称');
    }
    if (apkUrlValue is! String) {
      throw const UpdateException('更新清单缺少安装包地址');
    }
    final apkUrl = Uri.tryParse(apkUrlValue);
    if (apkUrl == null || apkUrl.scheme != 'https') {
      throw const UpdateException('安装包地址必须使用 HTTPS');
    }
    if (sha is! String || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sha.trim())) {
      throw const UpdateException('更新清单中的 SHA-256 无效');
    }
    final notes = _releaseNotes(decoded);
    return UpdateInfo(
      versionName: versionName.trim(),
      versionCode: versionCode,
      apkUrl: apkUrl,
      apkSha256: sha.trim().toLowerCase(),
      apkSize: apkSize,
      releaseNotes: notes,
      mandatory: decoded['mandatory'] == true,
    );
  }

  /// 放宽版清单解析：只校验证件编号与版本字段，不管产物。
  ///
  /// `platform`、`apkUrl`、`apkSha256`、`apkSize` 全部忽略 —— 它们描述的是
  /// Android 的安装包，iOS 用不上，却会让 [parseManifest] 直接抦掉清单。
  static AvailableVersion? parseAvailableVersion(
    String source, {
    required int currentVersionCode,
  }) {
    final decoded = _decodeManifest(source);
    final versionCode = _positiveInt(decoded['versionCode'], 'versionCode');
    if (versionCode <= currentVersionCode) return null;

    final versionName = decoded['versionName'];
    if (versionName is! String || versionName.trim().isEmpty) {
      throw const UpdateException('更新清单缺少版本名称');
    }
    return AvailableVersion(
      versionName: versionName.trim(),
      versionCode: versionCode,
      releaseNotes: _releaseNotes(decoded),
      mandatory: decoded['mandatory'] == true,
    );
  }

  static Map<String, dynamic> _decodeManifest(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const UpdateException('更新清单格式错误');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('更新清单根节点必须是对象');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const UpdateException('更新清单版本不受支持');
    }
    return decoded;
  }

  static List<String> _releaseNotes(Map<String, dynamic> decoded) {
    final notesValue = decoded['releaseNotes'];
    final notes = notesValue is List
        ? notesValue.whereType<String>().map((item) => item.trim()).toList()
        : <String>[];
    return notes.where((item) => item.isNotEmpty).toList();
  }

  Future<File> downloadApk(
    UpdateInfo update, {
    required void Function(int received, int total) onProgress,
  }) async {
    final directory = await _temporaryDirectory();
    final file = File('${directory.path}/kuangshuati-update.apk');
    if (await file.exists()) await file.delete();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'Kuangshuati-Android-Updater/1';
    IOSink? sink;
    var keepFile = false;
    try {
      final request = await client.getUrl(update.apkUrl);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException('下载安装包失败：HTTP ${response.statusCode}');
      }
      final expectedTotal = update.apkSize;
      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        received += chunk.length;
        if (received > expectedTotal) {
          throw const UpdateException('安装包大小与更新清单不一致');
        }
        sink.add(chunk);
        hasher.add(chunk);
        onProgress(received, expectedTotal);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      hasher.close();
      if (received != expectedTotal) {
        throw const UpdateException('安装包下载不完整');
      }
      final actualSha = digestSink.value?.toString();
      if (actualSha != update.apkSha256) {
        throw const UpdateException('安装包校验失败，请重新下载');
      }
      keepFile = true;
      return file;
    } on TimeoutException {
      throw const UpdateException('下载安装包超时，请稍后重试');
    } on SocketException {
      throw const UpdateException('下载安装包时网络连接中断');
    } finally {
      if (sink != null) await sink.close();
      client.close(force: true);
      if (!keepFile && await file.exists()) await file.delete();
    }
  }

  Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    await _channel.invokeMethod<void>('openInstallPermissionSettings');
  }

  Future<void> installApk(File file) async {
    await _channel.invokeMethod<void>('installApk', {'path': file.path});
  }

  static int _positiveInt(Object? value, String field) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      throw UpdateException('更新清单中的 $field 无效');
    }
    return parsed;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
