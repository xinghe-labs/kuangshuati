import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'update_service.dart';

Future<void> checkForAppUpdate(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  // 应用内更新靠下载 APK 交给系统安装器，只有 Android 有这条链路。
  // iOS/Web 上不拦的话会白下载 60MB 安装包，最后报“无法启动系统安装器”。
  if (!Platform.isAndroid) {
    if (manual && context.mounted) {
      _showMessage(context, '当前平台不支持应用内更新，请通过分发渠道获取新版本');
    }
    return;
  }
  final service = ref.read(updateServiceProvider);
  try {
    final update = await service.checkForUpdate();
    if (!context.mounted) return;
    if (update == null) {
      if (manual) _showMessage(context, '当前已是最新版本');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) => PopScope(
        canPop: !update.mandatory,
        child: AlertDialog(
          title: Text('发现新版本 ${update.versionName}'),
          content: _ReleaseNotes(update: update),
          actions: [
            if (!update.mandatory)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('稍后'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('下载更新'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: _UpdateDownloadDialog(service: service, update: update),
      ),
    );
  } on UpdateException catch (error) {
    if (context.mounted && manual) _showMessage(context, error.message);
  } on Exception {
    if (context.mounted && manual) {
      _showMessage(context, '检查更新失败，请稍后重试');
    }
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.update});

  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    final notes = update.releaseNotes.isEmpty
        ? const ['包含稳定性与使用体验改进。']
        : update.releaseNotes;
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('版本号 ${update.versionCode}'),
          const SizedBox(height: 12),
          ...notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('· '),
                  Expanded(child: Text(note)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DownloadStage { downloading, ready, permission, failed }

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({required this.service, required this.update});

  final UpdateService service;
  final UpdateInfo update;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  _DownloadStage _stage = _DownloadStage.downloading;
  double _progress = 0;
  String _message = '正在下载安装包';
  File? _file;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() {
      _stage = _DownloadStage.downloading;
      _progress = 0;
      _message = '正在下载安装包';
    });
    try {
      final file = await widget.service.downloadApk(
        widget.update,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() => _progress = received / total);
        },
      );
      final canInstall = await widget.service.canInstallPackages();
      if (!mounted) return;
      setState(() {
        _file = file;
        _progress = 1;
        _stage = canInstall ? _DownloadStage.ready : _DownloadStage.permission;
        _message = canInstall ? '安装包校验通过' : '需要允许安装未知来源应用';
      });
    } on UpdateException catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _DownloadStage.failed;
        _message = error.message;
      });
    }
  }

  Future<void> _install() async {
    try {
      if (!await widget.service.canInstallPackages()) {
        await widget.service.openInstallPermissionSettings();
        if (!mounted) return;
        setState(() {
          _stage = _DownloadStage.permission;
          _message = '完成授权后返回，再点击安装更新';
        });
        return;
      }
      final file = _file;
      if (file == null) throw const UpdateException('安装包不存在，请重新下载');
      await widget.service.installApk(file);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _stage = _DownloadStage.failed;
        _message = '无法启动系统安装器，请重新下载后再试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _stage == _DownloadStage.downloading;
    return AlertDialog(
      title: Text('更新到 ${widget.update.versionName}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (downloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 12),
              Text('${(_progress * 100).floor()}% · $_message'),
            ] else
              Text(_message),
            if (_stage == _DownloadStage.permission) ...[
              const SizedBox(height: 12),
              const Text(
                '这是 Android 的系统安全限制。应用会校验安装包，系统还会确认新包签名与当前版本一致。',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_stage == _DownloadStage.permission)
          FilledButton(
            onPressed: () async {
              await widget.service.openInstallPermissionSettings();
            },
            child: const Text('前往授权'),
          ),
        if (_stage == _DownloadStage.ready ||
            _stage == _DownloadStage.permission)
          FilledButton(onPressed: _install, child: const Text('安装更新')),
        if (_stage == _DownloadStage.failed) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton(onPressed: _download, child: const Text('重新下载')),
        ],
      ],
    );
  }
}
