import 'dart:io';

import 'package:flutter/services.dart';

/// 备份文件的系统级出入口：分享、保存到文件、从文件管理器选文件。
///
/// 全部走原生 MethodChannel，缺插件（桌面/测试环境）时安静降级为 null/false，
/// 由调用方决定如何提示，不抛异常打断流程。
class BackupPlatform {
  static const MethodChannel _channel = MethodChannel(
    'com.kuangshuati.app/backup',
  );

  static const String mimeType = 'application/octet-stream';

  /// 让用户把备份文件保存到系统任意位置（下载目录、网盘等）。
  static Future<bool> saveToFile({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    try {
      final saved = await _channel.invokeMethod<bool>('saveFile', {
        'name': suggestedName,
        'bytes': bytes,
      });
      return saved ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 通过系统分享面板发送备份文件（微信、邮箱、网盘…）。
  static Future<bool> share(File file) async {
    try {
      final shared = await _channel.invokeMethod<bool>('shareFile', {
        'path': file.path,
        'name': file.uri.pathSegments.last,
        'mime': mimeType,
      });
      return shared ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 打开系统文件选择器读取一个备份文件。
  static Future<PickedBackupFile?> pick() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('pickFile');
      if (result == null) return null;
      final bytes = result['bytes'];
      if (bytes is! Uint8List) return null;
      return PickedBackupFile(
        name: (result['name'] as String?) ?? '备份文件',
        bytes: bytes,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
