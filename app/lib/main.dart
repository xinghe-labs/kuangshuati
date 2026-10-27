import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'features/content/content_install_page.dart';
import 'features/content/content_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await buildKuangshuatiApp());
}

Future<ProviderScope> buildKuangshuatiApp({
  Directory? supportDirectory,
  AppDatabase? userDatabase,
  ContentManager? contentManager,
}) async {
  final manager =
      contentManager ??
      await ContentManager.create(supportDirectory: supportDirectory);
  if (manager.phase == ContentManagerPhase.checking) {
    await manager.initialize();
  }
  final stats = await manager.repository.stats();
  debugPrint(
    'Content ${stats.contentVersion}: '
    '${stats.questionCount} questions, ${stats.paperCount} papers',
  );
  return ProviderScope(
    overrides: [
      contentManagerProvider.overrideWith((ref) {
        ref.onDispose(manager.dispose);
        return manager;
      }),
      contentRepositoryProvider.overrideWith((ref) {
        return ref.watch(contentManagerProvider).repository;
      }),
      if (userDatabase != null)
        databaseProvider.overrideWith((ref) {
          ref.onDispose(userDatabase.close);
          return userDatabase;
        }),
    ],
    child: const KuangshuatiApp(),
  );
}

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
