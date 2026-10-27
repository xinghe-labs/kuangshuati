import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content/content_repository.dart';
import '../data/content/seed_content_repository.dart';
import '../data/database/app_database.dart';
import '../domain/models.dart';

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
