import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/content/content_repository.dart';
import '../../data/content/seed_content_repository.dart';
import '../../data/content/web_content_repository.dart';
import 'content_manager_base.dart';
import 'gzip_web.dart' if (dart.library.io) 'gzip_stub.dart';

/// Web 端的题库管理器。
///
/// 和移动端最大的不同：浏览器里没有「安装」这个概念，也没有 297 MiB 的完整
/// 数据库可下载。这里的做法是
///
/// 1. 下载 `web-content-manifest.json`（几百字节）拿版本号和校验值；
/// 2. 下载 `content-core.sqlite.gz`（约 36 MiB）——只有题目、试卷和图片索引，
///    不含图片字节；解压后灌进浏览器的 OPFS / IndexedDB，下次直接复用；
/// 3. 图片单独按需拉取（见 [WebContentRepository]），绝大多数题目根本用不到。
///
/// 所以这里的「进度」指的是核心库的下载进度，不是整个题库。
class WebContentManager extends ContentManagerBase {
  WebContentManager({required Uri baseUri, http.Client? client})
    : this._(baseUri, client ?? http.Client());

  WebContentManager._(this._baseUri, this._client);

  final Uri _baseUri;
  final http.Client _client;

  ContentRepository _repository = SeedContentRepository();
  ContentManagerPhase _phase = ContentManagerPhase.checking;
  WebContentRepository? _webRepository;
  WebContentManifest? _installedManifest;
  WebContentManifest? _availableManifest;
  double _progress = 0;
  String _stage = '正在检查题库';
  String? _errorMessage;
  bool _manifestCheckStarted = false;
  bool _disposed = false;

  @override
  ContentRepository get repository => _repository;

  @override
  ContentManagerPhase get phase => _phase;

  @override
  double get progress => _progress;

  @override
  String get stage => _stage;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get hasFullContent => _webRepository != null;

  WebContentManifest? get installedManifest => _installedManifest;

  WebContentManifest? get availableManifest => _availableManifest;

  @override
  bool get hasManifest => _availableManifest != null;

  @override
  String? get errorDetail => _errorMessage;

  @override
  bool get updateAvailable =>
      _availableManifest != null &&
      _installedManifest != null &&
      _availableManifest!.contentVersion != _installedManifest!.contentVersion;

  /// 打开浏览器里已有的题库副本（如果有）。没有就让页面去下载。
  Future<void> initialize() async {
    _phase = ContentManagerPhase.checking;
    _stage = '正在检查题库';
    _notify();
    try {
      // 先看浏览器里有没有装过。drift 的 initializeDatabase 只在首次
      // 创建数据库时被调用；这里传一个抛异常的 loader，用来判断
      // "已经存在就不该再下载" 的情况。
      _availableManifest = await _fetchManifest();
      final opened = await _openExisting();
      if (!opened) {
        _phase = ContentManagerPhase.needsDownload;
        _stage = '题库尚未下载';
      }
    } on Object catch (error) {
      _phase = ContentManagerPhase.failed;
      _stage = '无法获取题库信息';
      _errorMessage = friendlyWebContentError(error);
      debugPrint('WebContentManager initialize failed: $error');
    }
    _notify();
  }

  /// 打开浏览器里已有的题库副本。
  ///
  /// 没有副本时返回 false，由界面去触发下载。判断「有没有」只看虚拟文件
  /// 系统里存不存在库文件，不尝试打开数据库。
  Future<bool> _openExisting() async {
    final sqlite3Wasm = _resolveRuntime('sqlite3.wasm');
    final cached = await WebContentRepository.hasCachedDatabase(
      sqlite3Wasm: sqlite3Wasm,
    );
    if (!cached) return false;
    final repository = await WebContentRepository.open(
      sqlite3Wasm: sqlite3Wasm,
      databaseBytesLoader: () async => null,
      manifest: const {},
    );
    final stats = await repository.stats();
    if (stats.questionCount <= 0) {
      await repository.close();
      return false;
    }
    _webRepository = repository;
    _repository = repository;
    _phase = ContentManagerPhase.ready;
    _stage = '题库已就绪';
    return true;
  }

  @override
  Future<void> checkForManifest({bool silent = false}) async {
    if (_phase == ContentManagerPhase.downloading) return;
    if (_manifestCheckStarted && silent) return;
    _manifestCheckStarted = true;
    if (!silent) {
      _phase = ContentManagerPhase.checking;
      _stage = '正在获取最新题库信息';
      _errorMessage = null;
      _notify();
    }
    try {
      _availableManifest = await _fetchManifest();
      if (_webRepository == null) {
        _phase = ContentManagerPhase.needsDownload;
        _stage = '题库尚未下载';
      } else {
        _phase = ContentManagerPhase.ready;
        _stage = updateAvailable ? '发现新的题库版本' : '题库已是最新版本';
      }
      _errorMessage = null;
    } on Object catch (error) {
      if (_webRepository != null) {
        _phase = ContentManagerPhase.ready;
        _stage = '无法检查题库更新';
      } else {
        _phase = ContentManagerPhase.failed;
        _stage = '无法获取题库下载信息';
      }
      _errorMessage = friendlyWebContentError(error);
      debugPrint('WebContentManager checkForManifest failed: $error');
    }
    _notify();
  }

  @override
  Future<void> refresh() => checkForManifest(silent: true);

  Future<void>? _installFuture;

  @override
  Future<void> downloadAndInstall() {
    // 页面初始化时 checkForManifest 与自动下载可能同时触发；drift 对同一个
    // databaseName 只会保留第一个 worker，第二个连接的初始化端口会被丢弃，
    // 于是永远等不到初始数据。这里用单飞（single-flight）保证只有一个安装。
    return _installFuture ??= _install().whenComplete(() {
      _installFuture = null;
    });
  }

  Future<void> _install() async {
    if (_phase == ContentManagerPhase.downloading) return;
    _phase = ContentManagerPhase.downloading;
    _progress = 0;
    _stage = '正在下载题库';
    _errorMessage = null;
    _notify();
    WebContentRepository? opening;
    try {
      final manifest =
          _availableManifest ?? (_availableManifest = await _fetchManifest());
      final compressed = await _downloadCore(manifest);
      _stage = '正在解压题库';
      _notify();
      // 解压 178 MiB 要一会儿，让出一帧把进度文案先画出来。
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final bytes = await gunzipBytes(compressed);
      final previous = _webRepository;
      opening = await WebContentRepository.open(
        sqlite3Wasm: _resolveRuntime('sqlite3.wasm'),
        databaseBytesLoader: () async {
          return bytes;
        },
        manifest: {
          'contentVersion': manifest.contentVersion,
          'questionCount': manifest.questionCount,
          'paperCount': manifest.paperCount,
          'imageCount': manifest.imageCount,
        },
        // 图片走单独的按需接口，核心库里没有图片字节。
        imageBaseUri: _resolve('images/'),
      );
      await previous?.close();
      final installedStats = await opening.stats();
      debugPrint(
        'Web 题库安装完成：${installedStats.questionCount} 题 / '
        '${installedStats.paperCount} 套试卷',
      );
      _webRepository = opening;
      _repository = opening;
      _installedManifest = manifest;
      _progress = 1;
      _stage = '题库已就绪';
      _phase = ContentManagerPhase.ready;
      _notify();
    } on Object catch (error, stack) {
      debugPrint('$stack');
      try {
        await opening?.close();
      } on Object catch (closeError) {
        debugPrint('Web 题库安装失败后关闭连接也出错：$closeError');
      }
      _phase = ContentManagerPhase.failed;
      _stage = '题库下载失败';
      _errorMessage = friendlyWebContentError(error);
      debugPrint('WebContentManager downloadAndInstall failed: $error');
      _notify();
    }
  }

  Future<Uint8List> _downloadCore(WebContentManifest manifest) async {
    final uri = _resolve(manifest.corePath);
    final response = await _client.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw _WebContentException('题库服务器返回 HTTP ${response.statusCode}');
    }
    final total = response.contentLength ?? manifest.coreBytes;
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in response.stream) {
      builder.add(chunk);
      received += chunk.length;
      if (total > 0) {
        _progress = (received / total).clamp(0, 1);
        _notify();
      }
    }
    final payload = builder.takeBytes();
    if (payload.length != manifest.coreBytes) {
      throw _WebContentException(
        '题库文件大小不符：期望 ${manifest.coreBytes} 字节，实际 ${payload.length}',
      );
    }
    return payload;
  }

  Future<WebContentManifest> _fetchManifest() async {
    final response = await _client
        .get(_resolve('web-content-manifest.json'))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw _WebContentException('题库清单返回 HTTP ${response.statusCode}');
    }
    return WebContentManifest.parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  /// 运行时文件（sqlite3.wasm、drift worker）跟随应用站点根目录，
  /// 而不是题库目录：它们是构建产物的一部分，和题库版本无关。
  Uri _resolveRuntime(String file) => Uri.base.resolve(file);

  Uri _resolve(String relative) {
    final base = _baseUri.toString();
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized).resolve(relative);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _webRepository?.close();
    _webRepository = null;
    _client.close();
    super.dispose();
  }
}

/// Web 题库清单，对应 `web-content-manifest.json`。
class WebContentManifest {
  const WebContentManifest({
    required this.contentVersion,
    required this.questionCount,
    required this.paperCount,
    required this.imageCount,
    required this.corePath,
    required this.coreBytes,
    required this.coreSha256,
  });

  final String contentVersion;
  final int questionCount;
  final int paperCount;
  final int imageCount;
  final String corePath;
  final int coreBytes;
  final String coreSha256;

  static WebContentManifest parse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const _WebContentException('题库清单格式不正确');
    }
    final core = decoded['core'];
    if (core is! Map<String, dynamic>) {
      throw const _WebContentException('题库清单缺少 core 字段');
    }
    final path = core['path'];
    final bytes = core['bytes'];
    final sha = core['sha256'];
    if (path is! String || bytes is! num || sha is! String) {
      throw const _WebContentException('题库清单 core 字段不完整');
    }
    return WebContentManifest(
      contentVersion: decoded['contentVersion']?.toString() ?? 'unknown',
      questionCount: (decoded['questionCount'] as num?)?.toInt() ?? 0,
      paperCount: (decoded['paperCount'] as num?)?.toInt() ?? 0,
      imageCount: (decoded['imageCount'] as num?)?.toInt() ?? 0,
      corePath: path,
      coreBytes: bytes.toInt(),
      coreSha256: sha,
    );
  }
}

/// 把底层异常翻成用户能看懂的一句话。
String friendlyWebContentError(Object error) {
  if (error is _WebContentException) return error.message;
  if (error is TimeoutException) return '网络超时，请检查网络后重试。';
  return '题库处理失败，请刷新页面重试。';
}

class _WebContentException implements Exception {
  const _WebContentException(this.message);

  final String message;

  @override
  String toString() => message;
}
