import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/database/app_database.dart';
import 'features/content/content_manager.dart';
import 'features/content/content_manager_base.dart';

/// 原生端入口（Android / iOS / 桌面）。
///
/// 题库是一个完整的 SQLite 文件，随安装包分发或从 CDN 下载到应用目录，
/// 之后完全离线可用。
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
