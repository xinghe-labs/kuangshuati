import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Web 端的设置页平台条目：备份和应用更新在浏览器里都不成立，全部留空。
///
/// 练习记录保存在浏览器本地存储里，刷新不丢；清空浏览器数据才会丢，
/// 这是 Web 端固有的限制，与其放一个点了没反应的按钮，不如不显示。
class SettingsPlatform {
  const SettingsPlatform._();

  static Future<String> versionLabel(WidgetRef ref) async => 'Web 版';

  /// Web 端没有应用内更新：新版本随页面刷新生效，这里什么都不做。
  static void autoCheckUpdate(BuildContext context, WidgetRef ref) {}

  static List<SettingsPlatformAction> dataActions() => const [];

  static List<SettingsPlatformAction> aboutActions() => const [];

  /// 设置页「存储」条目的标题。
  static String get storageNoteTitle => '浏览器存储';

  /// 浏览器存储的限制提示。
  ///
  /// 题库要占 ~178 MiB，练习记录也存在同一个源下。无痕窗口、清理“网站数据”、
  /// 浏览器回收存储空间都会把两者一起抹掉。与其等用户刷了几百题才发现进度没了，
  /// 不如提前写清楚。
  static String get storageNote =>
      '题库约 178 MB 和练习记录都只存在这个浏览器里。清理浏览器数据、'
      '使用无痕窗口或浏览器回收存储空间都会让它们消失；换浏览器、换设备也不同步。';
}

/// 与原生端保持同名同形的数据类。
class SettingsPlatformAction {
  const SettingsPlatformAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context, WidgetRef ref) onTap;
}
