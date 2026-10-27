import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models.dart';

part 'app_database.g.dart';

class PracticeSessions extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get title => text()();
  TextColumn get paperId => text().nullable()();
  TextColumn get filtersJson => text().withDefault(const Constant('{}'))();
  TextColumn get questionIdsJson => text()();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  IntColumn get requestedCount => integer().nullable()();
  IntColumn get actualCount => integer()();
  IntColumn get timeLimitSeconds => integer().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get deadlineAt => integer().nullable()();
  TextColumn get revealMode => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get finalizedAt => integer().nullable()();
  TextColumn get contentVersion =>
      text().withDefault(const Constant('demo-1'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SessionQuestions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get questionId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, questionId};
}

class SessionAnswers extends Table {
  TextColumn get sessionId => text()();
  TextColumn get questionId => text()();
  TextColumn get selectedJson => text().withDefault(const Constant('[]'))();
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();
  BoolColumn get isCorrect => boolean().nullable()();
  BoolColumn get uncertain => boolean().withDefault(const Constant(false))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get answeredAt => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, questionId};
}

class ReviewItems extends Table {
  TextColumn get questionId => text()();
  TextColumn get source => text().withDefault(const Constant('practice'))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get blankCount => integer().withDefault(const Constant(0))();
  IntColumn get stage => integer().withDefault(const Constant(0))();
  IntColumn get nextReviewAt => integer().nullable()();
  BoolColumn get mastered => boolean().withDefault(const Constant(false))();
  TextColumn get lastResult => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

class Favorites extends Table {
  TextColumn get questionId => text()();
  IntColumn get createdAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {questionId};
}

class DailyStats extends Table {
  TextColumn get day => text()();
  IntColumn get answeredCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get sessionsCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

class ModuleStats extends Table {
  TextColumn get module => text()();
  IntColumn get answeredCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {module};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    PracticeSessions,
    SessionQuestions,
    SessionAnswers,
    ReviewItems,
    Favorites,
    DailyStats,
    ModuleStats,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'kuangshuati_user'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(sessionAnswers, sessionAnswers.uncertain);
      }
      if (from < 3) {
        // Demo question IDs are not part of the imported content database.
        await customStatement('DELETE FROM session_answers');
        await customStatement('DELETE FROM session_questions');
        await customStatement('DELETE FROM practice_sessions');
        await customStatement('DELETE FROM review_items');
        await customStatement('DELETE FROM favorites');
        await customStatement('DELETE FROM daily_stats');
        await customStatement('DELETE FROM module_stats');
      }
    },
    onCreate: (migrator) async {
      await migrator.createAll();
      await batch((batch) {
        batch.insertAll(appSettings, [
          const AppSettingsCompanion(
            key: Value('revealImmediately'),
            value: Value('true'),
          ),
          const AppSettingsCompanion(
            key: Value('showTimer'),
            value: Value('true'),
          ),
          const AppSettingsCompanion(
            key: Value('fontScale'),
            value: Value('1.0'),
          ),
          const AppSettingsCompanion(
            key: Value('defaultCount'),
            value: Value('10'),
          ),
        ]);
      });
    },
  );

  Stream<PracticeSession?> watchLatestActiveSession() {
    return (select(practiceSessions)
          ..where((row) => row.status.equals(SessionStatus.active.value))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<PracticeSession?> latestActiveSession() {
    return (select(practiceSessions)
          ..where((row) => row.status.equals(SessionStatus.active.value))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<PracticeSession?> sessionById(String id) {
    return (select(
      practiceSessions,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<List<SessionQuestion>> sessionQuestionRows(String sessionId) {
    return (select(sessionQuestions)
          ..where((row) => row.sessionId.equals(sessionId))
          ..orderBy([(row) => OrderingTerm.asc(row.position)]))
        .get();
  }

  Future<List<SessionAnswer>> answersForSession(String sessionId) {
    return (select(
      sessionAnswers,
    )..where((row) => row.sessionId.equals(sessionId))).get();
  }

  Future<List<ReviewItem>> allReviewItems() {
    return (select(reviewItems)..orderBy([
          (row) => OrderingTerm.asc(row.mastered),
          (row) => OrderingTerm.asc(row.nextReviewAt),
        ]))
        .get();
  }

  Stream<List<ReviewItem>> watchReviewItems() {
    return (select(reviewItems)..orderBy([
          (row) => OrderingTerm.asc(row.mastered),
          (row) => OrderingTerm.asc(row.nextReviewAt),
        ]))
        .watch();
  }

  Stream<List<DailyStat>> watchDailyStats() {
    return (select(
      dailyStats,
    )..orderBy([(row) => OrderingTerm.desc(row.day)])).watch();
  }

  Stream<List<ModuleStat>> watchModuleStats() {
    return (select(
      moduleStats,
    )..orderBy([(row) => OrderingTerm.desc(row.answeredCount)])).watch();
  }

  Future<List<Favorite>> allFavorites() => select(favorites).get();

  Stream<List<Favorite>> watchFavorites() => select(favorites).watch();

  Future<bool> isFavorite(String questionId) async {
    final row = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    return row != null;
  }

  Future<bool> toggleFavorite(String questionId) async {
    final existing = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    if (existing != null) {
      await (delete(
        favorites,
      )..where((item) => item.questionId.equals(questionId))).go();
      return false;
    }
    await into(favorites).insert(
      FavoritesCompanion.insert(
        questionId: questionId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return true;
  }

  Future<void> setFavoriteNote(String questionId, String note) async {
    final existing = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    if (existing == null && note.trim().isEmpty) return;
    await into(favorites).insertOnConflictUpdate(
      FavoritesCompanion.insert(
        questionId: questionId,
        createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        note: Value(note.trim()),
      ),
    );
  }

  Future<String> favoriteNote(String questionId) async {
    final row = await (select(
      favorites,
    )..where((item) => item.questionId.equals(questionId))).getSingleOrNull();
    return row?.note ?? '';
  }

  Future<String> getSetting(String key, String fallback) async {
    final row = await (select(
      appSettings,
    )..where((item) => item.key.equals(key))).getSingleOrNull();
    return row?.value ?? fallback;
  }

  Stream<String?> watchSetting(String key) {
    return (select(appSettings)..where((item) => item.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<String> createSession({
    required String id,
    required PracticeMode mode,
    required String title,
    required List<QuestionContent> questions,
    required RevealMode revealMode,
    String? paperId,
    int? requestedCount,
    int? timeLimitSeconds,
    Map<String, Object?> filters = const {},
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final deadline = timeLimitSeconds == null
        ? null
        : now + timeLimitSeconds * 1000;
    await transaction(() async {
      await into(practiceSessions).insert(
        PracticeSessionsCompanion.insert(
          id: id,
          mode: mode.name,
          title: title,
          paperId: Value(paperId),
          filtersJson: Value(jsonEncode(filters)),
          questionIdsJson: jsonEncode(
            questions.map((question) => question.id).toList(),
          ),
          requestedCount: Value(requestedCount),
          actualCount: questions.length,
          timeLimitSeconds: Value(timeLimitSeconds),
          deadlineAt: Value(deadline),
          revealMode: revealMode.value,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await batch((batch) {
        batch.insertAll(sessionQuestions, [
          for (var index = 0; index < questions.length; index++)
            SessionQuestionsCompanion.insert(
              sessionId: id,
              questionId: questions[index].id,
              position: index,
            ),
        ]);
      });
    });
    return id;
  }

  Future<void> saveAnswer({
    required String sessionId,
    required String questionId,
    required Set<String> selected,
    required bool submitted,
    required bool? isCorrect,
    required int durationMs,
    bool uncertain = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(sessionAnswers).insertOnConflictUpdate(
      SessionAnswersCompanion.insert(
        sessionId: sessionId,
        questionId: questionId,
        selectedJson: Value(jsonEncode(selected.toList()..sort())),
        submitted: Value(submitted),
        isCorrect: Value(isCorrect),
        uncertain: Value(uncertain),
        durationMs: Value(durationMs),
        answeredAt: Value(now),
      ),
    );
    await (update(practiceSessions)..where((row) => row.id.equals(sessionId)))
        .write(PracticeSessionsCompanion(updatedAt: Value(now)));
  }

  Future<void> saveProgress({
    required String sessionId,
    required int currentIndex,
    required int durationMs,
  }) {
    return (update(
      practiceSessions,
    )..where((row) => row.id.equals(sessionId))).write(
      PracticeSessionsCompanion(
        currentIndex: Value(currentIndex),
        durationMs: Value(durationMs),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> finalizeSession({
    required String sessionId,
    required Map<String, QuestionContent> questionLookup,
  }) async {
    final session = await sessionById(sessionId);
    if (session == null || session.status != SessionStatus.active.value) return;
    final questions = await sessionQuestionRows(sessionId);
    final answers = await answersForSession(sessionId);
    final answerByQuestion = {
      for (final answer in answers) answer.questionId: answer,
    };
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    var answeredCount = 0;
    var correctCount = 0;
    var totalDurationMs = 0;

    await transaction(() async {
      for (final row in questions) {
        final question = questionLookup[row.questionId];
        if (question == null) continue;
        final answer = answerByQuestion[row.questionId];
        final selected = _decodeSelected(answer?.selectedJson);
        final isCorrect = selected.isNotEmpty && question.isCorrect(selected);
        final blank = selected.isEmpty;
        if (!blank) answeredCount++;
        if (isCorrect) correctCount++;
        totalDurationMs += answer?.durationMs ?? 0;

        await into(sessionAnswers).insertOnConflictUpdate(
          SessionAnswersCompanion.insert(
            sessionId: sessionId,
            questionId: row.questionId,
            selectedJson: Value(jsonEncode(selected.toList()..sort())),
            submitted: const Value(true),
            isCorrect: Value(isCorrect),
            uncertain: Value(answer?.uncertain ?? false),
            durationMs: Value(answer?.durationMs ?? 0),
            answeredAt: Value(answer?.answeredAt ?? nowMs),
          ),
        );

        await _updateReview(
          question: question,
          isCorrect: isCorrect,
          blank: blank,
          now: now,
        );
      }

      final day = _localDay(now);
      final daily = await (select(
        dailyStats,
      )..where((row) => row.day.equals(day))).getSingleOrNull();
      await into(dailyStats).insertOnConflictUpdate(
        DailyStatsCompanion.insert(
          day: day,
          answeredCount: Value((daily?.answeredCount ?? 0) + answeredCount),
          correctCount: Value((daily?.correctCount ?? 0) + correctCount),
          durationMs: Value((daily?.durationMs ?? 0) + totalDurationMs),
          sessionsCount: Value((daily?.sessionsCount ?? 0) + 1),
        ),
      );

      final moduleTotals = <String, _ModuleTotal>{};
      for (final row in questions) {
        final question = questionLookup[row.questionId];
        if (question == null) continue;
        final answer = answerByQuestion[row.questionId];
        final selected = _decodeSelected(answer?.selectedJson);
        final total = moduleTotals.putIfAbsent(
          question.module,
          _ModuleTotal.new,
        );
        if (selected.isNotEmpty) {
          total.answered++;
          if (question.isCorrect(selected)) total.correct++;
        }
        total.durationMs += answer?.durationMs ?? 0;
      }
      for (final entry in moduleTotals.entries) {
        final existing = await (select(
          moduleStats,
        )..where((row) => row.module.equals(entry.key))).getSingleOrNull();
        await into(moduleStats).insertOnConflictUpdate(
          ModuleStatsCompanion.insert(
            module: entry.key,
            answeredCount: Value(
              (existing?.answeredCount ?? 0) + entry.value.answered,
            ),
            correctCount: Value(
              (existing?.correctCount ?? 0) + entry.value.correct,
            ),
            durationMs: Value(
              (existing?.durationMs ?? 0) + entry.value.durationMs,
            ),
            updatedAt: nowMs,
          ),
        );
      }

      await (update(
        practiceSessions,
      )..where((row) => row.id.equals(sessionId))).write(
        PracticeSessionsCompanion(
          status: Value(SessionStatus.submitted.value),
          finalizedAt: Value(nowMs),
          updatedAt: Value(nowMs),
        ),
      );
    });
  }

  Future<void> markReviewMastered(String questionId, bool mastered) async {
    await (update(
      reviewItems,
    )..where((row) => row.questionId.equals(questionId))).write(
      ReviewItemsCompanion(
        mastered: Value(mastered),
        nextReviewAt: Value(
          mastered ? null : DateTime.now().millisecondsSinceEpoch,
        ),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _updateReview({
    required QuestionContent question,
    required bool isCorrect,
    required bool blank,
    required DateTime now,
  }) async {
    final existing = await (select(
      reviewItems,
    )..where((row) => row.questionId.equals(question.id))).getSingleOrNull();
    if (isCorrect && existing == null) return;

    final currentStage = existing?.stage ?? 0;
    final nextStage = isCorrect ? (currentStage + 1).clamp(0, 4) : 0;
    final mastered = isCorrect && nextStage >= 4;
    final intervalDays = const [1, 3, 7, 15, 30][nextStage];
    await into(reviewItems).insertOnConflictUpdate(
      ReviewItemsCompanion.insert(
        questionId: question.id,
        source: Value(existing?.source ?? 'practice'),
        wrongCount: Value(
          (existing?.wrongCount ?? 0) + (!isCorrect && !blank ? 1 : 0),
        ),
        blankCount: Value((existing?.blankCount ?? 0) + (blank ? 1 : 0)),
        stage: Value(nextStage),
        nextReviewAt: Value(
          mastered
              ? null
              : now.add(Duration(days: intervalDays)).millisecondsSinceEpoch,
        ),
        mastered: Value(mastered),
        lastResult: Value(blank ? 'blank' : (isCorrect ? 'correct' : 'wrong')),
        updatedAt: now.millisecondsSinceEpoch,
      ),
    );
  }

  Set<String> _decodeSelected(String? value) {
    if (value == null || value.isEmpty) return {};
    return (jsonDecode(value) as List<dynamic>).cast<String>().toSet();
  }

  String _localDay(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}

class _ModuleTotal {
  int answered = 0;
  int correct = 0;
  int durationMs = 0;
}
