import 'platform_capabilities_io.dart'
    if (dart.library.js_interop) 'platform_capabilities_web.dart';

/// 各平台能力开关。
///
/// 界面里有些功能只对原生端有意义：备份要写本地文件并调系统「保存到」，
/// 应用更新要下载 APK 覆盖安装。浏览器里这两件事都做不了，与其让按钮点下去
/// 才报错，不如直接不显示。
///
/// 用条件导入而不是运行时 `kIsWeb` 判断，是因为相关实现（`dart:io`、
/// 原生插件）在 Web 上根本无法编译；必须让编译器彻底不加载那份代码。
class PlatformCapabilities {
  const PlatformCapabilities._();

  /// 是否支持导出/恢复备份文件。
  static bool get supportsBackup => platformSupportsBackup;

  /// 是否支持应用自更新（下载并安装新版本）。
  static bool get supportsAppUpdate => platformSupportsAppUpdate;

  /// 是否支持在系统文件管理器里挑选文件。
  static bool get supportsFilePicker => platformSupportsFilePicker;
}
