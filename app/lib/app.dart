import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'features/content/content_install_page.dart';
import 'features/content/content_manager_base.dart';
import 'features/reminder/reminder_scheduler.dart'
    if (dart.library.js_interop) 'features/reminder/reminder_scheduler_web.dart';

/// 应用外壳：题库没准备好时停在下载页，准备好后进路由。
///
/// 原生端和 Web 端的题库来源不同，但"先有题库才能刷题"这个顺序一样，
/// 所以外壳共用，入口各自装配自己的题库管理器。
class KuangshuatiApp extends ConsumerStatefulWidget {
  const KuangshuatiApp({super.key});

  @override
  ConsumerState<KuangshuatiApp> createState() => _KuangshuatiAppState();
}

class _KuangshuatiAppState extends ConsumerState<KuangshuatiApp> {
  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(contentManagerProvider);
    // 题库就绪 = 数据库可用：补排一次每日提醒（幂等，覆盖上次未排上/
    // 系统重启丢排期的情况；Web 端是 no-op）。
    ref.listen<ContentManagerBase>(contentManagerProvider, (prev, next) {
      if (next.phase == ContentManagerPhase.ready &&
          prev?.phase != ContentManagerPhase.ready) {
        unawaited(syncReminderFromSettings(ref.read(databaseProvider)));
      }
    });
    final scale = ref.watch(fontScaleProvider).value ?? 1;
    final ready = manager.phase == ContentManagerPhase.ready;
    Widget applyTextScale(BuildContext context, Widget? child) {
      final media = MediaQuery.of(context);
      final systemScale = media.textScaler.scale(1.0);
      final effective = effectiveTextScale(scale, systemScale);
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

/// 把「App 内题目字号」与「系统字号」合并成一个最终的文字缩放倍数。
///
/// 不能相乘：系统字号 1.3 × 设置里选“小”0.9 = 1.17，用户明明选了“小”，
/// 字却比标准还大，设置项形同虚设。
///
/// 但也不能取较大值：设置里的“小”就是 0.9，而系统字号正常就是 1.0，
/// max(0.9, 1.0) 永远返回 1.0——用户点“小”完全没反应（中老年用户
/// 想调小字号时最容易踩到）。
///
/// 改成：以系统字号为基准，按设置档位的相对比例缩放。
/// 设置 0.9 = 标准字号的 90%，1.15 = 115%，两者都真正生效，
/// 同时系统字号调大时整体跟着变大（不会把系统设置覆盖掉）。
double effectiveTextScale(double appScale, double systemScale) {
  // 设置里的“标准”是 1.0，用它当基准把设置值换算成倍率。
  final factor = appScale <= 0 ? 1.0 : appScale;
  return (systemScale * factor).clamp(0.85, 1.6);
}
