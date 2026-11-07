import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reminder/reminder_scheduler.dart'
    if (dart.library.js_interop) '../features/reminder/reminder_scheduler_web.dart';
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

/// 单题限时（秒）。0 = 不限时（默认）。存 settings 表。
final questionTimeLimitProvider = StreamProvider<int>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('questionTimeLimitSec')
      .map((value) => value == null ? 0 : int.tryParse(value) ?? 0);
});

/// 每日练习提醒：开关 + 提醒时间（分钟数）。
final reminderEnabledProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('reminderEnabled')
      .map((value) => value == 'true');
});

final reminderMinutesProvider = StreamProvider<int>((ref) {
  return ref
      .watch(databaseProvider)
      .watchSetting('reminderMinutesOfDay')
      .map(parseReminderMinutes);
});

/// 当前环境是否支持本地提醒（Web 端为 false，设置页据此隐藏入口）。
final reminderSupportedProvider = Provider<bool>(
  (ref) => reminderScheduler.supported,
);

/// 一条「最近练习」记录：会话本身 + 作答概况。
class RecentSessionEntry {
  const RecentSessionEntry({required this.session, required this.summary});

  final PracticeSession session;
  final SessionSummary summary;
}

/// 最近完成（已交卷/已结束）的练习。
///
/// 早先成绩只存在结果页：按一下「返回首页」，sessionId 就再也拿不到，
/// 用户想回看「昨天那组模考多少分」完全无处可去。统计页用它列出历史记录。
///
/// 必须监听会话表：交卷/结束时列表要立刻出现这一组，不能等重启 App。
final recentSessionsProvider = StreamProvider<List<RecentSessionEntry>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchRecentSessions(limit: 20).asyncMap((sessions) async {
    final entries = <RecentSessionEntry>[];
    for (final session in sessions) {
      entries.add(
        RecentSessionEntry(
          session: session,
          summary: await database.summarizeSession(session.id),
        ),
      );
    }
    return entries;
  });
});
