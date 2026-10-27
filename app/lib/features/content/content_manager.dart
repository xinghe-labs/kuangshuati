import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/content/content_repository.dart';
import '../../data/content/full_content_repository.dart';
import '../../data/content/seed_content_repository.dart';
import 'content_package_service.dart';

enum ContentManagerPhase {
  checking,
  needsDownload,
  downloading,
  ready,
  failed,
}

class ContentManager extends ChangeNotifier {
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
  bool _manifestCheckStarted = false;

  ContentRepository get repository => _repository;

  ContentManagerPhase get phase => _phase;

  ContentPackageManifest? get installedManifest => _installedManifest;

  ContentPackageManifest? get availableManifest => _availableManifest;

  double get progress => _progress;

  String get stage => _stage;

  String? get errorMessage => _errorMessage;

  bool get hasFullContent => _fullRepository != null;

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
          _errorMessage = '已安装题库损坏：$error';
        }
      }
      _phase = ContentManagerPhase.needsDownload;
      _stage = '首次使用需要下载离线题库';
      notifyListeners();
    } on Object catch (error) {
      _phase = ContentManagerPhase.failed;
      _stage = '无法检查离线题库';
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

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
      if (_fullRepository == null) {
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
      } else {
        _phase = ContentManagerPhase.failed;
        _stage = '无法获取题库下载信息';
      }
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<bool> downloadAndInstall() async {
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
      _phase = ContentManagerPhase.ready;
      _stage = '离线题库安装完成';
      notifyListeners();
      return true;
    } on Object catch (error) {
      _errorMessage = error.toString();
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
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _fullRepository?.close();
    _fullRepository = null;
    super.dispose();
  }
}
