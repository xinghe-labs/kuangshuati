import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';

import '../data/content/content_repository.dart';
import '../data/content/seed_content_repository.dart';
import '../data/database/app_database.dart';
import '../domain/models.dart';
import '../features/backup/backup_service.dart';
import '../features/content/content_manager_base.dart';
import '../features/updates/update_service.dart';

final contentManagerProvider = ChangeNotifierProvider<ContentManagerBase>((ref) {
  throw UnimplementedError(
    'Content manager must be initialized by the app root',
  );
});

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final repository = SeedContentRepository();
  ref.onDispose(repository.close);
  return repository;
});

final contentStatsProvider = FutureProvider<ContentStats>((ref) {
  return Future.value(ref.watch(contentRepositoryProvider).stats());
});

final recentPapersProvider = FutureProvider<List<Paper>>((ref) {
  return Future.value(
    ref.watch(contentRepositoryProvider).recentPapers(limit: 5),
  );
});

final latestActiveSessionProvider = StreamProvider<PracticeSession?>((ref) {
  return ref.watch(databaseProvider).watchLatestActiveSession();
});

/// 进行中练习里“已提交多少题”。
///
/// 首页原先只显示 `上次练到第 N / M 题`（N 是当前停留位置）。用户只答了
/// 1 题、用答题卡翻到最后一题，首页就显示「第 5 / 5 题」，看起来像练完了。
/// 补上真实已答数量，用户才知道还剩多少。
///
/// 必须用 StreamProvider 订阅答题表：早先是 FutureProvider.family，只读一次
/// 就把结果缓存住了。用户从练习页退出、回首页继续做几题，首页的“已答 1 题，
/// 还剩 4 题”永远不更新（实测答完 5 题仍显示 1），用户会以为进度没保存。
final activeSessionAnsweredProvider = StreamProvider.family<int, String>((
  ref,
  sessionId,
) {
  return ref.watch(databaseProvider).watchSubmittedCount(sessionId);
});

final reviewItemsProvider = StreamProvider<List<ReviewItem>>((ref) {
  return ref.watch(databaseProvider).watchReviewItems();
});

final favoritesProvider = StreamProvider<List<Favorite>>((ref) {
  // 只显示用户主动收藏的题；写笔记但未收藏的行走 notesProvider。
  return ref.watch(databaseProvider).watchFavoriteItems();
});

final notesProvider = StreamProvider<List<Favorite>>((ref) {
  return ref.watch(databaseProvider).watchNoteItems();
});

final dailyStatsProvider = StreamProvider<List<DailyStat>>((ref) {
  return ref.watch(databaseProvider).watchDailyStats();
});

final moduleStatsProvider = StreamProvider<List<ModuleStat>>((ref) {
  return ref.watch(databaseProvider).watchModuleStats();
});

final practiceStreakProvider = StreamProvider<PracticeStreak>((ref) {
  return ref.watch(databaseProvider).watchPracticeStreak();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    database: ref.watch(databaseProvider),
    directoryOf: getApplicationDocumentsDirectory,
    appVersionLabel: () async {
      final version = await ref.read(updateServiceProvider).currentVersion();
      return '${version.name} (${version.code})';
    },
    contentInfo: () async {
      final stats = await ref.read(contentRepositoryProvider).stats();
      return {
        'contentVersion': stats.contentVersion,
        'questionCount': stats.questionCount,
        'paperCount': stats.paperCount,
      };
    },
  );
});

final fontScaleProvider = StreamProvider<double>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('fontScale')
      .map((value) => double.tryParse(value ?? '') ?? 1);
});

final revealImmediatelyProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('revealImmediately')
      .map((value) => value != 'false');
});

final showTimerProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('showTimer')
      .map((value) => value != 'false');
});
