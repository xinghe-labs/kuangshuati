import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path_provider/path_provider.dart';

import '../data/content/content_repository.dart';
import '../data/content/seed_content_repository.dart';
import '../data/database/app_database.dart';
import '../domain/models.dart';
import '../features/backup/backup_service.dart';
import '../features/content/content_manager.dart';
import '../features/updates/update_service.dart';

final contentManagerProvider = ChangeNotifierProvider<ContentManager>((ref) {
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

final reviewItemsProvider = StreamProvider<List<ReviewItem>>((ref) {
  return ref.watch(databaseProvider).watchReviewItems();
});

final favoritesProvider = StreamProvider<List<Favorite>>((ref) {
  return ref.watch(databaseProvider).watchFavorites();
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
