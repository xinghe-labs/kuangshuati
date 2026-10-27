import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/network/proxy_http_client.dart';

const contentManifestUrl = String.fromEnvironment(
  'CONTENT_MANIFEST_URL',
  defaultValue:
      'https://content.example.com/content-manifest.json',
);
const contentHttpProxy = String.fromEnvironment(
  'CONTENT_HTTP_PROXY',
  defaultValue: 'http://127.0.0.1:10808',
);
const _appVersionCode = int.fromEnvironment(
  'APP_VERSION_CODE',
  defaultValue: 1,
);

class ContentPackageException implements Exception {
  const ContentPackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContentPackageManifest {
  const ContentPackageManifest({
    required this.contentVersion,
    required this.minimumAppVersionCode,
    required this.questionCount,
    required this.paperCount,
    required this.imageCount,
    required this.databaseBytes,
    required this.databaseSha256,
    required this.packageUrl,
    required this.packageBytes,
    required this.packageSha256,
  });

  final String contentVersion;
  final int minimumAppVersionCode;
  final int questionCount;
  final int paperCount;
  final int imageCount;
  final int databaseBytes;
  final String databaseSha256;
  final Uri packageUrl;
  final int packageBytes;
  final String packageSha256;

  /// 解析清单 JSON。
  ///
  /// [strictHttps] 为 true 时（网络清单）要求 packageUrl 必须是 HTTPS；
  /// 读取本机已安装记录时传 false，避免规则收紧后本机记录被误判损坏。
  static ContentPackageManifest parse(
    String source, {
    bool strictHttps = true,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ContentPackageException('题库清单格式错误');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ContentPackageException('题库清单根节点必须是对象');
    }
    if (decoded['schemaVersion'] != 1 ||
        decoded['platform'] != 'android' ||
        decoded['format'] != 'sqlite-gzip') {
      throw const ContentPackageException('题库清单版本或平台不受支持');
    }
    final version = decoded['contentVersion'];
    final packageUrlValue = decoded['packageUrl'];
    if (version is! String || version.trim().isEmpty) {
      throw const ContentPackageException('题库清单缺少内容版本');
    }
    if (packageUrlValue is! String) {
      throw const ContentPackageException('题库清单缺少下载地址');
    }
    final packageUrl = Uri.tryParse(packageUrlValue);
    if (packageUrl == null ||
        (strictHttps ? packageUrl.scheme != 'https' : !packageUrl.hasScheme)) {
      throw const ContentPackageException('题库下载地址必须使用 HTTPS');
    }
    final minimumAppVersionCode = _nonNegativeInt(
      decoded['minimumAppVersionCode'],
      'minimumAppVersionCode',
    );
    if (_appVersionCode < minimumAppVersionCode) {
      throw ContentPackageException(
        '当前应用版本过低，请先更新应用（需要版本号 $minimumAppVersionCode）',
      );
    }
    final packageSha = _digest(decoded['packageSha256'], 'packageSha256');
    final databaseSha = _digest(decoded['databaseSha256'], 'databaseSha256');
    return ContentPackageManifest(
      contentVersion: version.trim(),
      minimumAppVersionCode: minimumAppVersionCode,
      questionCount: _positiveInt(decoded['questionCount'], 'questionCount'),
      paperCount: _positiveInt(decoded['paperCount'], 'paperCount'),
      imageCount: _nonNegativeInt(decoded['imageCount'], 'imageCount'),
      databaseBytes: _positiveInt(decoded['databaseBytes'], 'databaseBytes'),
      databaseSha256: databaseSha,
      packageUrl: packageUrl,
      packageBytes: _positiveInt(decoded['packageBytes'], 'packageBytes'),
      packageSha256: packageSha,
    );
  }

  static int _positiveInt(Object? value, String field) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed <= 0) {
      throw ContentPackageException('题库清单中的 $field 无效');
    }
    return parsed;
  }

  static int _nonNegativeInt(Object? value, String field) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed < 0) {
      throw ContentPackageException('题库清单中的 $field 无效');
    }
    return parsed;
  }

  static String _digest(Object? value, String field) {
    if (value is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(value.trim())) {
      throw ContentPackageException('题库清单中的 $field 无效');
    }
    return value.trim().toLowerCase();
  }
}

class ContentPackageService {
  ContentPackageService({
    this.manifestUrl = contentManifestUrl,
    this.proxy = contentHttpProxy,
    this._supportDirectory,
    this._temporaryDirectory,
    this.segmentCount = 4,
  });

  final String manifestUrl;
  final String proxy;
  final Directory? _supportDirectory;
  final Directory? _temporaryDirectory;
  final int segmentCount;

  Future<Directory> get _support async =>
      _supportDirectory ?? await getApplicationSupportDirectory();

  Future<Directory> get _temporary async =>
      _temporaryDirectory ?? await getTemporaryDirectory();

  Future<ContentPackageManifest> fetchManifest() async {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || uri.scheme != 'https') {
      throw const ContentPackageException('题库清单地址必须使用 HTTPS');
    }
    try {
      return await _fetchManifest(uri, useProxy: true);
    } catch (error) {
      if (normalizeHttpProxy(proxy) == null ||
          error.toString().contains('版本过低')) {
        rethrow;
      }
      return _fetchManifest(uri, useProxy: false);
    }
  }

  Future<ContentPackageManifest> _fetchManifest(
    Uri uri, {
    required bool useProxy,
  }) async {
    final client = createHttpClient(proxy: useProxy ? proxy : '');
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw ContentPackageException('题库服务器返回 HTTP ${response.statusCode}');
      }
      return ContentPackageManifest.parse(
        await response.transform(utf8.decoder).join(),
      );
    } on TimeoutException {
      throw const ContentPackageException('获取题库清单超时');
    } on SocketException {
      throw const ContentPackageException('无法连接题库服务器');
    } finally {
      client.close(force: true);
    }
  }

  Future<ContentPackageManifest?> readInstalledManifest() async {
    final support = await _support;
    final manifestFile = File(
      '${support.path}${Platform.pathSeparator}content-installed.json',
    );
    final databaseFile = File(
      '${support.path}${Platform.pathSeparator}content.sqlite',
    );
    if (!await manifestFile.exists() || !await databaseFile.exists()) {
      return null;
    }
    try {
      final manifest = ContentPackageManifest.parse(
        await manifestFile.readAsString(),
        strictHttps: false,
      );
      if (await databaseFile.length() != manifest.databaseBytes) return null;
      return manifest;
    } on Exception {
      return null;
    }
  }

  Future<ContentPackageManifest> install(
    ContentPackageManifest manifest, {
    required void Function(double progress, String stage) onProgress,
  }) async {
    if (segmentCount < 1 || segmentCount > 8) {
      throw const ContentPackageException('题库下载分片数必须在 1 到 8 之间');
    }
    final support = await _support;
    final temporary = await _temporary;
    await support.create(recursive: true);
    await temporary.create(recursive: true);
    final downloadDirectory = Directory(
      '${temporary.path}${Platform.pathSeparator}content-download',
    );
    final databaseTarget = File(
      '${support.path}${Platform.pathSeparator}content.sqlite',
    );
    final manifestTarget = File(
      '${support.path}${Platform.pathSeparator}content-installed.json',
    );
    final databaseTemporary = File(
      '${support.path}${Platform.pathSeparator}content.sqlite.installing',
    );
    final manifestTemporary = File(
      '${support.path}${Platform.pathSeparator}content-installed.json.installing',
    );
    final previousDatabase = File(
      '${support.path}${Platform.pathSeparator}content.sqlite.previous',
    );
    final previousManifest = File(
      '${support.path}${Platform.pathSeparator}content-installed.json.previous',
    );

    await databaseTemporary.deleteIfExists();
    await manifestTemporary.deleteIfExists();
    try {
      onProgress(0, '正在准备题库下载');
      final segments = await _downloadSegments(
        manifest,
        downloadDirectory,
        onProgress: (progress) => onProgress(progress * 0.8, '正在下载题库'),
      );
      onProgress(0.82, '正在校验题库压缩包');
      await _decodeDatabase(manifest, segments, databaseTemporary);
      onProgress(0.94, '正在安装离线题库');
      await manifestTemporary.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'platform': 'android',
          'format': 'sqlite-gzip',
          'contentVersion': manifest.contentVersion,
          'minimumAppVersionCode': manifest.minimumAppVersionCode,
          'questionCount': manifest.questionCount,
          'paperCount': manifest.paperCount,
          'imageCount': manifest.imageCount,
          'databaseBytes': manifest.databaseBytes,
          'databaseSha256': manifest.databaseSha256,
          'packageUrl': manifest.packageUrl.toString(),
          'packageBytes': manifest.packageBytes,
          'packageSha256': manifest.packageSha256,
        }),
        flush: true,
      );
      await previousDatabase.deleteIfExists();
      await previousManifest.deleteIfExists();
      if (await databaseTarget.exists()) {
        await databaseTarget.rename(previousDatabase.path);
      }
      if (await manifestTarget.exists()) {
        await manifestTarget.rename(previousManifest.path);
      }
      try {
        await databaseTemporary.rename(databaseTarget.path);
        await manifestTemporary.rename(manifestTarget.path);
      } on Object {
        await databaseTarget.deleteIfExists();
        await manifestTarget.deleteIfExists();
        if (await previousDatabase.exists()) {
          await previousDatabase.rename(databaseTarget.path);
        }
        if (await previousManifest.exists()) {
          await previousManifest.rename(manifestTarget.path);
        }
        rethrow;
      }
      await previousDatabase.deleteIfExists();
      await previousManifest.deleteIfExists();
      await downloadDirectory.delete(recursive: true);
      onProgress(1, '题库安装完成');
      return manifest;
    } on ContentPackageException {
      await databaseTemporary.deleteIfExists();
      rethrow;
    } on Exception catch (error) {
      await databaseTemporary.deleteIfExists();
      throw ContentPackageException('安装题库失败：$error');
    }
  }

  Future<List<File>> _downloadSegments(
    ContentPackageManifest manifest,
    Directory directory, {
    required void Function(double progress) onProgress,
  }) async {
    final metadataFile = File(
      '${directory.path}${Platform.pathSeparator}download.json',
    );
    var resume = false;
    if (await metadataFile.exists()) {
      try {
        final metadata = jsonDecode(await metadataFile.readAsString()) as Map;
        resume =
            metadata['packageSha256'] == manifest.packageSha256 &&
            metadata['packageBytes'] == manifest.packageBytes &&
            metadata['segmentCount'] == segmentCount;
      } on Exception {
        resume = false;
      }
    }
    if (!resume && await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
    await metadataFile.writeAsString(
      jsonEncode({
        'packageSha256': manifest.packageSha256,
        'packageBytes': manifest.packageBytes,
        'segmentCount': segmentCount,
      }),
      flush: true,
    );

    final chunks = _segmentRanges(manifest.packageBytes, segmentCount);
    final files = <File>[];
    final downloaded = <int>[];
    for (var index = 0; index < chunks.length; index++) {
      final file = File(
        '${directory.path}${Platform.pathSeparator}segment.$index.part',
      );
      files.add(file);
      var existing = await file.exists() ? await file.length() : 0;
      final expected = chunks[index].end - chunks[index].start + 1;
      if (existing > expected) {
        await file.writeAsBytes(const [], flush: true);
        existing = 0;
      }
      downloaded.add(existing);
    }
    void report() {
      final received = downloaded.fold<int>(0, (total, item) => total + item);
      onProgress((received / manifest.packageBytes).clamp(0, 1));
    }

    report();
    await Future.wait([
      for (var index = 0; index < chunks.length; index++)
        _downloadSegment(
          manifest,
          chunks[index],
          files[index],
          downloaded,
          index,
          report,
        ),
    ]);
    report();
    return files;
  }

  List<({int start, int end})> _segmentRanges(int bytes, int count) {
    final ranges = <({int start, int end})>[];
    final base = bytes ~/ count;
    var start = 0;
    for (var index = 0; index < count; index++) {
      final end = index == count - 1 ? bytes - 1 : start + base - 1;
      ranges.add((start: start, end: end));
      start = end + 1;
    }
    return ranges;
  }

  Future<void> _downloadSegment(
    ContentPackageManifest manifest,
    ({int start, int end}) range,
    File file,
    List<int> downloaded,
    int index,
    void Function() report,
  ) async {
    final expected = range.end - range.start + 1;
    if (!await file.exists()) {
      await file.writeAsBytes(const [], flush: true);
    }
    var attempts = 0;
    while (await file.length() < expected) {
      attempts += 1;
      final usesProxy = normalizeHttpProxy(proxy) != null && attempts.isOdd;
      var current = await file.length();
      final requestStart = range.start + current;
      final client = createHttpClient(proxy: usesProxy ? proxy : '');
      RandomAccessFile? output;
      try {
        final request = await client.getUrl(manifest.packageUrl);
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=$requestStart-${range.end}',
        );
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != HttpStatus.partialContent) {
          throw ContentPackageException(
            '题库服务器不支持分段下载：HTTP ${response.statusCode}',
          );
        }
        output = await file.open(mode: FileMode.append);
        await for (final chunk in response.timeout(
          const Duration(seconds: 60),
        )) {
          current += chunk.length;
          if (current > expected) {
            throw const ContentPackageException('题库分片大小超出清单');
          }
          await output.writeFrom(chunk);
          downloaded[index] = current;
          report();
        }
      } on Exception catch (error) {
        if (attempts >= 4) {
          if (error is ContentPackageException) rethrow;
          throw ContentPackageException('下载题库失败：$error');
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * attempts));
      } finally {
        await output?.close();
        client.close(force: true);
      }
    }
  }

  Future<void> _decodeDatabase(
    ContentPackageManifest manifest,
    List<File> segments,
    File target,
  ) async {
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    Stream<List<int>> compressedStream() async* {
      for (final file in segments) {
        await for (final chunk in file.openRead()) {
          hasher.add(chunk);
          yield chunk;
        }
      }
    }

    final output = await target.open(mode: FileMode.write);
    var databaseBytes = 0;
    try {
      await for (final chunk in gzip.decoder.bind(compressedStream())) {
        databaseBytes += chunk.length;
        if (databaseBytes > manifest.databaseBytes) {
          throw const ContentPackageException('题库解压后大小超出清单');
        }
        await output.writeFrom(chunk);
      }
      await output.flush();
    } finally {
      await output.close();
      hasher.close();
    }
    if (digestSink.value?.toString() != manifest.packageSha256) {
      throw const ContentPackageException('题库压缩包校验失败');
    }
    if (databaseBytes != manifest.databaseBytes) {
      throw ContentPackageException(
        '题库大小不一致：期望 ${manifest.databaseBytes}，实际 $databaseBytes',
      );
    }
    final database = sqlite3.open(target.path, mode: OpenMode.readOnly);
    try {
      final integrity = database.select('PRAGMA quick_check').first.columnAt(0);
      if (integrity != 'ok') {
        throw ContentPackageException('题库完整性检查失败：$integrity');
      }
    } finally {
      database.close();
    }
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

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}
