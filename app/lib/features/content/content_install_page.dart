import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'content_manager_base.dart';

class ContentInstallPage extends ConsumerStatefulWidget {
  const ContentInstallPage({super.key});

  @override
  ConsumerState<ContentInstallPage> createState() => _ContentInstallPageState();
}

class _ContentInstallPageState extends ConsumerState<ContentInstallPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkManifestIfNeeded();
    });
  }

  void _checkManifestIfNeeded() {
    final manager = ref.read(contentManagerProvider);
    if (manager.phase == ContentManagerPhase.downloading) return;
    if (!manager.hasManifest) {
      manager.checkForManifest();
    }
    // 题库包很大且会消耗流量，不再静默自动下载：
    // 先拿到清单，然后由用户确认后再开始。
  }

  Future<void> _confirmAndDownload() async {
    final manager = ref.read(contentManagerProvider);
    if (!manager.hasManifest) {
      await manager.checkForManifest();
      if (!mounted) return;
      if (!manager.hasManifest) return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(manager.hasFullContent ? '下载题库更新？' : '下载离线题库？'),
        content: const Text(
          '安装包约 140MB，建议在 Wi-Fi 环境下下载；'
          '使用移动网络可能产生较多流量费用。'
          '下载完成后做题全程离线可用。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不下载'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('开始下载'),
          ),
        ],
      ),
    );
    if (confirmed == true) await manager.downloadAndInstall();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(contentManagerProvider);
    final manifest = manager.hasManifest;
    final downloading = manager.phase == ContentManagerPhase.downloading;
    final checking = manager.phase == ContentManagerPhase.checking;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    manager.hasFullContent ? '需要更新离线题库' : '需要下载离线题库',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '题库只在下载时联网。安装完成后，做题、看解析和错题复习均可离线使用。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (downloading || checking) ...[
                    const SizedBox(height: 24),
                    // 阶段文字与百分比同行：百分比用等宽数字，跳动时不会左右抳。
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            manager.stage,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        if (downloading) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${(manager.progress * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 与统计页的进度条同一种写法（softFill 轨道 + ink 填充），
                    // 只是这条是页面主进度，所以粗一点。
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: downloading ? manager.progress : null,
                        minHeight: 8,
                        backgroundColor: AppColors.softFill,
                        valueColor: AlwaysStoppedAnimation(AppColors.ink),
                      ),
                    ),
                  ],
                  if (manager.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.negativeFill,
                        border: Border.all(color: AppColors.negative),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            manager.errorMessage!,
                            style: TextStyle(color: AppColors.negative),
                          ),
                          // 原文只给调试构建看：发布版不把 SocketException、
                          // 本机端口这类信息倒给用户。与主文案重复时不展示，
                          // 否则同一句话会出现两遍。
                          if (kDebugMode &&
                              manager.errorDetail != null &&
                              manager.errorDetail != manager.errorMessage) ...[
                            const SizedBox(height: 8),
                            Text(
                              manager.errorDetail!,
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: checking || downloading
                        ? null
                        : manifest
                        ? _confirmAndDownload
                        : manager.checkForManifest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        downloading
                            ? '正在下载'
                            : !manifest
                            ? '重新检查'
                            : manager.hasFullContent
                            ? '下载并更新'
                            : '开始下载',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
