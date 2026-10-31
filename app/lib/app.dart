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
      final systemScale = media.textScaler.scale(1.0);
      final effective = (scale * systemScale).clamp(0.9, 1.6);
      // 跟随系统深浅模式同步全局色表：MaterialApp 用 darkTheme +
      // ThemeMode.system 触发整树重建，页面代码读 AppColors 拿到对应色。
      AppColors.current = media.platformBrightness == Brightness.dark
                ? AppPalette.dark
                : AppPalette.light;
      return MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(effective)),
        child: child ?? const SizedBox.shrink(),
      );
    }

    if (!ready) {
      return MaterialApp(
        title: '狂刷题',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(dark: true),
        themeMode: ThemeMode.system,
        home: const ContentInstallPage(),
        builder: applyTextScale,
      );
    }
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '狂刷题',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(dark: true),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: applyTextScale,
    );
  }
}
