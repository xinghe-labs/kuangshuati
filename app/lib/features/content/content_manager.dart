import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/content/content_repository.dart';
import '../../data/content/full_content_repository.dart';
import '../../data/content/seed_content_repository.dart';
import 'content_import_service.dart';
import 'content_manager_base.dart';
import 'content_package_service.dart';

/// 没有已安装题库时，是否用内置演示题库兜底。
///
/// 默认在 debug 构建开启：克隆仓库后 `flutter run` 就能直接进入练习，
/// 不必先下载约 145 MB 的离线题库包。release 构建保持关闭，
/// 线上行为与之前一致（首屏仍是下载页）。
/// 需要验证真实下载流程时用 `--dart-define=KUANGSHUATI_DEMO=false` 关掉。
const bool kDemoContentFallback = bool.fromEnvironment(
  'KUANGSHUATI_DEMO',
  defaultValue: kDebugMode,
);

/// 把底层异常翻成用户能看懂的一句话。
///
/// 直接展示 `SocketException: Connection refused ... errno = 111`
/// 只会让用户困惑（还会暴露本机代理端口），而真正需要它的人只看日志。
String friendlyContentError(Object error) {
  if (error is ContentPackageException) {
    return error.message;
  }
  if (error is ContentImportException) {
    return error.message;
  }
  if (error is SocketException ||
      error is HandshakeException ||
      error is HttpException) {
    return '网络不可用或连接被打断，请检查网络后重试。';
  }
  if (error is FileSystemException) {
    return '本机存储不可写或空间不足，请清理空间后重试。';
  }
  return '题库处理失败，请重试。';
}

class ContentManager extends ContentManagerBase {
  ContentManager({
    required ContentRepository seedRepository,
    Directory? supportDirectory,
    ContentPackageService? packageService,
  }) : _repository = seedRepository,
       _seedRepository = seedRepository,
       _supportDirectory = supportDirectory,
       _packageService =
           packageService ??
           ContentPackageService(supportDirectory: supportDirectory);

  ContentManager.forTesting(ContentRepository repository)
    : _repository = repository,
      _seedRepository = repository,
      _supportDirectory = null,
      _packageService = null,
      _phase = ContentManagerPhase.ready;

  final ContentRepository _seedRepository;
  final Directory? _supportDirectory;
  final ContentPackageService? _packageService;

  ContentRepository _repository;
  ContentManagerPhase _phase = ContentManagerPhase.checking;
  ContentPackageManifest? _installedManifest;
  ContentPackageManifest? _availableManifest;
  FullContentRepository? _fullRepository;
  double _progress = 0;
  String _stage = '正在检查离线题库';
  String? _errorMessage;
  String? _errorDetail;
  bool _manifestCheckStarted = false;
  bool _disposed = false;

  /// 当前是否靠内置演示题库支撑（没有已安装的离线题库）。
  bool _demoFallback = false;

  @override
  ContentRepository get repository => _repository;

  @override
  ContentManagerPhase get phase => _phase;

  ContentPackageManifest? get installedManifest => _installedManifest;

  ContentPackageManifest? get availableManifest => _availableManifest;

  @override
  bool get hasManifest => _availableManifest != null;

  @override
  double get progress => _progress;

  @override
  String get stage => _stage;

  @override
  String? get errorMessage => _errorMessage;

  /// 底层异常原文，只在调试构建里展示，发布版只给用户看 [errorMessage]。
  @override
  String? get errorDetail => _errorDetail;

  @override
  bool get hasFullContent => _fullRepository != null;

  @override
  bool get updateAvailable =>
      _availableManifest != null &&
      _installedManifest != null &&
      _availableManifest!.contentVersion != _installedManifest!.contentVersion;

  ContentPackageService get _service {
    final service = _packageService;
    if (service == null) {
      throw const ContentPackageException('测试内容管理器未配置题库下载服务');
    }
    return service;
  }

  /// 切到内置演示题库：repository 用 seed，phase 直接 ready，
  /// 让没有题库包的开发/试用环境也能走完整练习闭环。
  void _enterDemoFallback() {
    _repository = _seedRepository;
    _demoFallback = true;
    _phase = ContentManagerPhase.ready;
    _stage = '正在使用内置演示题库（${SeedContentRepository.questions.length} 题）';
  }

  /// 把异常存成「用户能看懂的一句 + 调试用的原文」。
  void _rememberError(Object error) {
    debugPrint('ContentManager error: $error');
    _errorMessage = friendlyContentError(error);
    _errorDetail = error.toString();
  }

  static Future<ContentManager> create({
    Directory? supportDirectory,
    ContentPackageService? packageService,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    return ContentManager(
      seedRepository: SeedContentRepository(),
      supportDirectory: support,
      packageService: packageService,
    );
  }

  Future<void> initialize() async {
    _phase = ContentManagerPhase.checking;
    _stage = '正在检查离线题库';
    _errorMessage = null;
    notifyListeners();
    try {
      final installed = await _service.readInstalledManifest();
      if (installed != null) {
        try {
          _fullRepository = await FullContentRepository.openInstalled(
            supportDirectory: _supportDirectory,
          );
          _repository = _fullRepository!;
          _installedManifest = installed;
          _phase = ContentManagerPhase.ready;
          _stage = '离线题库已就绪';
          notifyListeners();
          return;
        } on Object catch (error) {
          _errorDetail = error.toString();
          _errorMessage = '已安装的离线题库损坏，需要重新下载。';
        }
      }
      if (kDemoContentFallback) {
        _enterDemoFallback();
      } else {
        _phase = ContentManagerPhase.needsDownload;
        _stage = '首次使用需要下载离线题库';
      }
      notifyListeners();
    } on Object catch (error) {
      _phase = ContentManagerPhase.failed;
      _stage = '无法检查离线题库';
      _rememberError(error);
      notifyListeners();
    }
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
      notifyListeners();
    }
    try {
      _availableManifest = await _service.fetchManifest();
      if (_fullRepository == null && _demoFallback) {
        _enterDemoFallback();
      } else if (_fullRepository == null) {
        _phase = ContentManagerPhase.needsDownload;
        _stage = '离线题库尚未安装';
      } else {
        _phase = ContentManagerPhase.ready;
        _stage = updateAvailable ? '发现新的题库版本' : '离线题库已是最新版本';
      }
      _errorMessage = null;
    } on Object catch (error) {
      if (_fullRepository != null) {
        _phase = ContentManagerPhase.ready;
        _stage = '无法检查题库更新';
      } else if (_demoFallback) {
        _phase = ContentManagerPhase.ready;
        _stage = '无法检查题库更新，继续使用内置演示题库';
      } else {
        _phase = ContentManagerPhase.failed;
        _stage = '无法获取题库下载信息';
      }
      _rememberError(error);
    }
    notifyListeners();
  }

  @override
  Future<void> refresh() => checkForManifest(silent: true);

  @override
  Future<bool> downloadAndInstall() async {
    // 并发重入保护：下载进行中重复触发会竞争临时文件，
    // 曾导致偶发 SqliteException(14)，这里直接拒绝重复进入。
    if (_phase == ContentManagerPhase.downloading) return false;
    try {
      final manifest =
          _availableManifest ??
          (_availableManifest = await _service.fetchManifest());
      final previous = _fullRepository;
      previous?.close();
      _fullRepository = null;
      _phase = ContentManagerPhase.downloading;
      _progress = 0;
      _stage = '正在准备题库下载';
      _errorMessage = null;
      notifyListeners();
      await _service.install(
        manifest,
        onProgress: (progress, stage) {
          _progress = progress;
          _stage = stage;
          notifyListeners();
        },
      );
      final installed = await FullContentRepository.openInstalled(
        supportDirectory: _supportDirectory,
      );
      _fullRepository = installed;
      _repository = installed;
      _installedManifest = manifest;
      _progress = 1;
      _demoFallback = false;
      _phase = ContentManagerPhase.ready;
      _stage = '离线题库安装完成';
      notifyListeners();
      return true;
    } on Object catch (error) {
      _rememberError(error);
      try {
        _fullRepository = await FullContentRepository.openInstalled(
          supportDirectory: _supportDirectory,
        );
        _repository = _fullRepository!;
        _phase = ContentManagerPhase.ready;
        _stage = '题库更新失败，继续使用已安装版本';
      } on Object {
        _repository = _seedRepository;
        _phase = _fullRepository != null
            ? ContentManagerPhase.ready
            : ContentManagerPhase.failed;
        _stage = _fullRepository != null ? '题库更新失败' : '题库安装失败';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> reopenInstalled() async {
    _fullRepository?.close();
    _fullRepository = null;
    try {
      _fullRepository = await FullContentRepository.openInstalled(
        supportDirectory: _supportDirectory,
      );
      _repository = _fullRepository!;
      _phase = ContentManagerPhase.ready;
    } on Object catch (error) {
      _repository = _seedRepository;
      _phase = ContentManagerPhase.failed;
      _rememberError(error);
    }
    notifyListeners();
  }

  /// 从本地 JSON 导入自制题库。安装与下载共用同一套原子落盘，
  /// 失败时旧题库完好；成功后当前仓库切到新题库。
  @override
  Future<void> importBankFile(
    String path, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    // 与下载互斥：两边都在改同一套 content.sqlite* 文件。
    if (_phase == ContentManagerPhase.downloading) {
      throw const ContentImportException('题库正在下载或导入中，请稍候');
    }
    // 注意：不提前 close 旧仓库。导入期间 repositoryProvider 会随进度通知
    // 重新解析，首页还在 watch 它；旧连接保持打开，新库装好后才切换。
    _phase = ContentManagerPhase.downloading;
    _progress = 0;
    _stage = '正在准备导入';
    _errorMessage = null;
    notifyListeners();
    FullContentRepository? opened;
    try {
      final summary =
          await ContentImportService(
            supportDirectory: _supportDirectory,
          ).importFromFile(
            path,
            onProgress: (progress, stage) {
              _progress = progress;
              _stage = stage;
              notifyListeners();
            },
          );
      opened = await FullContentRepository.openInstalled(
        supportDirectory: _supportDirectory,
      );
      final previous = _fullRepository;
      _fullRepository = opened;
      _repository = opened;
      previous?.close();
      _installedManifest = await _service.readInstalledManifest();
      _progress = 1;
      _demoFallback = false;
      _phase = ContentManagerPhase.ready;
      _stage = '题库导入完成：${summary.questionCount} 题 / ${summary.paperCount} 份卷子';
      notifyListeners();
    } on Object catch (error) {
      _rememberError(error);
      if (opened != null) {
        try {
          opened.close();
        } on Object catch (closeError) {
          debugPrint('导入失败后关闭新库连接出错：$closeError');
        }
      }
      // 安装是原子的：失败时旧题库文件与旧连接都完好，直接回滚。
      if (_fullRepository != null) {
        _repository = _fullRepository!;
        _phase = ContentManagerPhase.ready;
        _stage = '导入失败，继续使用原题库';
      } else {
        _repository = _seedRepository;
        _phase = ContentManagerPhase.failed;
        _stage = '题库导入失败';
      }
      notifyListeners();
      // 把原始异常抛给调用方（设置页拿 message 弹提示）。
      if (error is ContentImportException) rethrow;
      throw ContentImportException(friendlyContentError(error));
    }
  }

  @override
  void dispose() {
    // contentManagerProvider 是 ChangeNotifierProvider：容器销毁时会自动
    // dispose 一次，而 main.dart 里又挂了 ref.onDispose(manager.dispose)，
    // 于是会二次 dispose 并触发 “used after being disposed” 断言。
    if (_disposed) return;
    _disposed = true;
    _fullRepository?.close();
    _fullRepository = null;
    super.dispose();
  }

  /// 下载是异步的，Provider/页面可能先被销毁（退出、热重启、换题库）。
  /// 此时再 notifyListeners 会触发 “used after being disposed” 断言崩溃。
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
