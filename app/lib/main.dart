import 'dart:io';

import 'package:flutter/foundation.dart';
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
  // stats() 要 COUNT 三张大表（实测 ~30 ms，手机上更久），而这里只为了打一行
  // 调试日志。发布构建不跑它，首帧前就只剩 ATTACH + 结构探针。
  if (kDebugMode) {
    final stats = await manager.repository.stats();
    debugPrint(
      'Content ${stats.contentVersion}: '
      '${stats.questionCount} questions, ${stats.paperCount} papers',
    );
  }
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
