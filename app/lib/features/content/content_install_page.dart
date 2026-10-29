import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import 'content_manager.dart';

class ContentInstallPage extends ConsumerStatefulWidget {
  const ContentInstallPage({super.key});

  @override
  ConsumerState<ContentInstallPage> createState() => _ContentInstallPageState();
}

class _ContentInstallPageState extends ConsumerState<ContentInstallPage> {
  bool _autoStartAttempted = false;

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
    if (manager.availableManifest == null) {
      manager.checkForManifest();
    }
    // 未安装题库时进入页面自动开始下载，下载进度照常展示。
    if (!manager.hasFullContent && !_autoStartAttempted) {
      _autoStartAttempted = true;
      manager.downloadAndInstall();
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(contentManagerProvider);
    final manifest = manager.availableManifest;
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
                    LinearProgressIndicator(
                      value: downloading ? manager.progress : null,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      downloading
                          ? '${manager.stage} ${(manager.progress * 100).toStringAsFixed(0)}%'
                          : manager.stage,
                      style: Theme.of(context).textTheme.bodySmall,
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
                            style: const TextStyle(color: AppColors.negative),
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
                              style: const TextStyle(
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
                        : manifest == null
                        ? manager.checkForManifest
                        : manager.downloadAndInstall,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Text(
                        downloading
                            ? '正在下载'
                            : manifest == null
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
