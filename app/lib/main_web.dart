import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/providers.dart';
import 'data/database/app_database.dart';
import 'features/content/web_content_manager.dart';

/// Web 端入口。
///
/// 与原生端最大的区别在题库：浏览器拿不到 297 MiB 的完整 SQLite 文件，
/// 这里改为「核心题库 + 按需图片」两层（见 [WebContentManager]）。
///
/// 题库清单默认放在同一站点的 `content/` 下，可以用
/// `--dart-define=CONTENT_BASE_URL=...` 指向别处（例如本地静态服务器或 CDN）。
const String _contentBaseUrl = String.fromEnvironment(
  'CONTENT_BASE_URL',
  defaultValue: 'content/',
);

/// 构建戳：用于确认浏览器加载的是哪一次构建，避免被旧产物误导。
const String _buildStamp = 'BUILDSTAMP-20261029-A';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: avoid_print
  print(_buildStamp);
  runApp(await buildKuangshuatiWebApp());
}

Future<ProviderScope> buildKuangshuatiWebApp({
  AppDatabase? userDatabase,
  WebContentManager? contentManager,
}) async {
  final manager =
      contentManager ??
      WebContentManager(baseUri: Uri.parse(_contentBaseUrl));
  await manager.initialize();
  final stats = await manager.repository.stats();
  debugPrint(
    'Web content ${stats.contentVersion}: '
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
