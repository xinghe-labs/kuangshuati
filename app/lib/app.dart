import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/content/content_install_page.dart';
import 'features/content/content_manager_base.dart';

/// 应用外壳：题库没准备好时停在下载页，准备好后进路由。
///
/// 原生端和 Web 端的题库来源不同，但"先有题库才能刷题"这个顺序一样，
/// 所以外壳共用，入口各自装配自己的题库管理器。
class KuangshuatiApp extends ConsumerWidget {
  const KuangshuatiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(contentManagerProvider);
    final scale = ref.watch(fontScaleProvider).value ?? 1;
    final ready = manager.phase == ContentManagerPhase.ready;
    Widget applyTextScale(BuildContext context, Widget? child) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: TextScaler.linear(scale.clamp(0.9, 1.3)),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    }

    if (!ready) {
      return MaterialApp(
        title: '狂刷题',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const ContentInstallPage(),
        builder: applyTextScale,
      );
    }
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '狂刷题',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      builder: applyTextScale,
    );
  }
}
