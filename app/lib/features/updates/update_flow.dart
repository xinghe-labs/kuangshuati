import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  // iOS 装不了 APK，但可以告诉用户「有新版本」并引导去下新的 ipa；
  // 桌面/Web 连这条路都没有。
  if (!Platform.isAndroid) {
    if (!Platform.isIOS) {
      if (manual && context.mounted) {
        _showMessage(context, '当前平台不支持应用内更新，请通过分发渠道获取新版本');
      }
      return;
    }
    await _checkForIosVersion(context, ref, manual: manual);
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
          content: _ReleaseNotes(
          versionCode: update.versionCode,
          notes: update.releaseNotes,
        ),
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

/// iOS：只能告知 + 引导去下载新 ipa（Sideloadly 覆盖安装），无法在应用内装。
///
/// 与 Android 的差别：不锁死对话框（安装本就得手动做，强行阻断只会让人
/// 没法用 App），也不下载任何东西。
Future<void> _checkForIosVersion(
  BuildContext context,
  WidgetRef ref, {
  required bool manual,
}) async {
  final service = ref.read(updateServiceProvider);
  try {
    final update = await service.checkForVersionOnly();
    if (!context.mounted) return;
    if (update == null) {
      if (manual) _showMessage(context, '当前已是最新版本');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('发现新版本 ${update.versionName}'),
        content: _ReleaseNotes(
          versionCode: update.versionCode,
          notes: update.releaseNotes,
          hint: 'iOS 需要下载新的 ipa，用 Sideloadly 覆盖安装；同一个 Apple ID 签名会保留作答记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去下载'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    if (await service.openReleasePage()) return;
    // 原生通道打不开（旧版原生实现/桌面端）时，至少把链接给到手上。
    await Clipboard.setData(const ClipboardData(text: iosReleasePageUrl));
    if (!context.mounted) return;
    _showMessage(context, '已复制下载链接，用 Safari 打开即可');
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
  const _ReleaseNotes({
    required this.versionCode,
    required this.notes,
    this.hint,
  });

  final int versionCode;
  final List<String> notes;

  /// 平台相关的额外提示（例如 iOS 得自己签名安装）。
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final lines = notes.isEmpty ? const ['包含稳定性与使用体验改进。'] : notes;
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('版本号 $versionCode'),
          const SizedBox(height: 12),
          ...lines.map(
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
          if (hint != null) ...[
            const SizedBox(height: 5),
            Text(
              hint!,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
          ],
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

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog>
    with WidgetsBindingObserver {
  _DownloadStage _stage = _DownloadStage.downloading;
  double _progress = 0;
  String _message = '正在下载安装包';
  File? _file;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _download();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 用户去系统设置授完权回到应用时，自动重查授权状态，
  // 否则对话框永远停在“前往授权”这一步。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_stage != _DownloadStage.permission) return;
    widget.service.canInstallPackages().then((granted) {
      if (!mounted || !granted) return;
      setState(() {
        _stage = _DownloadStage.ready;
        _message = '安装包校验通过';
      });
    });
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
    } on Exception {
      // 兼底：磁盘空间不足、文件读写失败等非预期错误也会把对话框
      // 卡死在“正在下载”，必须给出失败态和重试入口。
      if (!mounted) return;
      setState(() {
        _stage = _DownloadStage.failed;
        _message = '下载失败，请检查网络和存储空间后重试';
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
              Text(
                '这是 Android 的系统安全限制。应用会校验安装包，系统还会确认新包签名与当前版本一致。',
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_stage == _DownloadStage.downloading && !widget.update.mandatory)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        // 授权未完成时只给“前往授权”，避免和“安装更新”并排出现
        // 两个主按钮让用户不知道点哪个。
        if (_stage == _DownloadStage.permission)
          FilledButton(
            onPressed: () async {
              await widget.service.openInstallPermissionSettings();
            },
            child: const Text('前往授权'),
          ),
        if (_stage == _DownloadStage.ready)
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
