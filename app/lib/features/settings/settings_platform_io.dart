import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../backup/backup_page.dart';
import '../updates/update_flow.dart';

/// 设置页里「只对原生端成立」的条目和动作。
///
/// 备份要写本地文件、更新要下载安装包，浏览器里都做不到。把这些实现放进
/// 单独文件并让设置页条件导入，Web 构建就不会去编译 `dart:io`。
class SettingsPlatform {
  const SettingsPlatform._();

  /// 「关于」里展示的版本号。
  static Future<String> versionLabel(WidgetRef ref) async {
    final version = await ref.read(updateServiceProvider).currentVersion();
    return '${version.name} (${version.code})';
  }

  /// 数据区的额外条目（备份与恢复）。
  static List<SettingsPlatformAction> dataActions() => [
    SettingsPlatformAction(
      icon: Icons.backup_outlined,
      title: '备份与恢复',
      subtitle: '导出或恢复练习记录，换机、重装不丢进度',
      onTap: (context, ref) => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (context) => const BackupPage())),
    ),
  ];

  /// 启动时静默检查一次应用更新（仅 Android 有应用内更新链路）。
  static void autoCheckUpdate(BuildContext context, WidgetRef ref) {
    checkForAppUpdate(context, ref, manual: false);
  }

  /// 「关于」区的额外条目（检查更新）。
  static List<SettingsPlatformAction> aboutActions() => [
    SettingsPlatformAction(
      icon: Icons.system_update_alt,
      title: '检查更新',
      subtitle: '启动时自动检查，也支持手动检查',
      onTap: (context, ref) => checkForAppUpdate(context, ref, manual: true),
    ),
  ];

  /// 设置页「存储」条目的标题。
  static String get storageNoteTitle => '本机存储';

  /// 原生端的存储说明：数据落在本机，可用备份导出。
  static String get storageNote => '练习记录只保存在这台设备，可随时导出备份，不联网上传。';
}

/// 一个平台专属的设置条目，由设置页统一渲染。
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
