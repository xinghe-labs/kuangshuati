import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/stats/stats_page.dart';

void main() {
  final repository = SeedContentRepository();
  final questions = repository.allQuestions.take(4).toList();
  final lookup = {for (final question in questions) question.id: question};

  late DateTime now;
  late AppDatabase database;

  setUp(() {
    // 固定在中午，避免测试恰好跨过当地午夜导致自然日漂移。
    now = DateTime(2026, 3, 1, 12);
    database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  Future<void> practice({
    required String sessionId,
    required DateTime day,
    int answered = 1,
  }) async {
    now = day;
    await database.createSession(
      id: sessionId,
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions.take(answered).toList(),
      revealMode: RevealMode.immediate,
    );
    for (var index = 0; index < answered; index++) {
      final question = questions[index];
      await database.saveAnswer(
        sessionId: sessionId,
        questionId: question.id,
        selected: question.correctAnswers,
        submitted: true,
        isCorrect: true,
        durationMs: 100,
      );
    }
    await database.finalizeSession(
      sessionId: sessionId,
      questionLookup: lookup,
    );
  }

  test(
    'counts streak by local natural day and breaks on a skipped day',
    () async {
      await practice(sessionId: 'd1', day: DateTime(2026, 3, 1, 9));
      var streak = await database.practiceStreak();
      expect(streak.currentDays, 1);
      expect(streak.totalDays, 1);
      expect(streak.lastDay, '2026-03-01');

      // 同一天第二组不增加天数。
      await practice(sessionId: 'd1b', day: DateTime(2026, 3, 1, 22));
      streak = await database.practiceStreak();
      expect(streak.currentDays, 1);
      expect(streak.totalDays, 1);

      // 连续第二天 → 2。
      await practice(sessionId: 'd2', day: DateTime(2026, 3, 2, 8));
      streak = await database.practiceStreak();
      expect(streak.currentDays, 2);
      expect(streak.totalDays, 2);

      // 跳过一个整天 → 断档，从 1 重新开始。
      await practice(sessionId: 'd4', day: DateTime(2026, 3, 4, 8));
      streak = await database.practiceStreak();
      expect(streak.currentDays, 1);
      expect(streak.totalDays, 3);
    },
  );

  test('rolling the clock back never increases the streak', () async {
    await practice(sessionId: 'a', day: DateTime(2026, 3, 5, 9));
    await practice(sessionId: 'b', day: DateTime(2026, 3, 6, 9));
    var streak = await database.practiceStreak();
    expect(streak.currentDays, 2);

    // 回拨到前一天再练：既不加天数，也不清零。
    await practice(sessionId: 'c', day: DateTime(2026, 3, 5, 21));
    streak = await database.practiceStreak();
    expect(streak.currentDays, 2);
    expect(streak.lastDay, '2026-03-06');

    // 回拨到很久以前再练，同样不增加。
    await practice(sessionId: 'd', day: DateTime(2026, 2, 20, 9));
    streak = await database.practiceStreak();
    expect(streak.currentDays, 2);
    expect(streak.lastDay, '2026-03-06');
  });

  test(
    'a session with no answered question does not count as a practice day',
    () async {
      now = DateTime(2026, 3, 1, 12);
      await database.createSession(
        id: 'blank',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: questions.take(2).toList(),
        revealMode: RevealMode.immediate,
      );
      await database.finalizeSession(
        sessionId: 'blank',
        questionLookup: lookup,
      );

      final streak = await database.practiceStreak();
      expect(streak.currentDays, 0);
      expect(streak.totalDays, 0);
      final daily = await database.watchDailyStats().first;
      expect(daily.single.answeredCount, 0);
    },
  );

  test('finalizing twice does not double count statistics', () async {
    await practice(
      sessionId: 'once',
      day: DateTime(2026, 3, 1, 9),
      answered: 3,
    );
    final before = (await database.watchDailyStats().first).single;
    final beforeModules = await database.watchModuleStats().first;

    // 自动交卷和手动交卷可能同时触发，第二次必须完全无效。
    await database.finalizeSession(sessionId: 'once', questionLookup: lookup);

    final after = (await database.watchDailyStats().first).single;
    final afterModules = await database.watchModuleStats().first;
    expect(after.answeredCount, before.answeredCount);
    expect(after.correctCount, before.correctCount);
    expect(after.durationMs, before.durationMs);
    expect(after.sessionsCount, before.sessionsCount);
    expect(
      afterModules.fold<int>(0, (sum, item) => sum + item.answeredCount),
      beforeModules.fold<int>(0, (sum, item) => sum + item.answeredCount),
    );
    final session = await database.sessionById('once');
    expect(session?.status, SessionStatus.submitted.value);
  });

  test('restores question order, selections, index and elapsed time', () async {
    now = DateTime(2026, 3, 1, 9);
    await database.createSession(
      id: 'resume',
      mode: PracticeMode.paper,
      title: '2024 国考',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
      requestedCount: questions.length,
    );
    await database.saveAnswer(
      sessionId: 'resume',
      questionId: questions[1].id,
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 4200,
    );
    await database.saveProgress(
      sessionId: 'resume',
      currentIndex: 1,
      durationMs: 9000,
    );

    // 强杀后重新读取：会话、题序、选择、题号和计时都必须原样回来。
    final active = await database.latestActiveSession();
    expect(active?.id, 'resume');
    expect(active?.currentIndex, 1);
    expect(active?.durationMs, 9000);
    final rows = await database.sessionQuestionRows('resume');
    expect(
      rows.map((row) => row.questionId).toList(),
      questions.map((question) => question.id).toList(),
    );
    final answers = await database.answersForSession('resume');
    final restored = answers.singleWhere(
      (answer) => answer.questionId == questions[1].id,
    );
    expect(restored.selectedJson, '["A"]');
    expect(restored.submitted, isFalse);
    expect(restored.durationMs, 4200);
  });

  test('does not name a weak module from fewer than ten answers', () {
    ModuleStat stat(String module, int answered, int correct) => ModuleStat(
      module: module,
      answeredCount: answered,
      correctCount: correct,
      durationMs: 1000,
      updatedAt: 0,
    );

    // 3 题错 1 题看起来很糟，但样本不足，不能当弱项。
    expect(weakestModule([stat('数量关系', 3, 2)]), isNull);
    expect(
      weakestModule([stat('数量关系', 9, 6), stat('言语理解', 40, 34)])?.module,
      '言语理解',
    );
    // 样本够了以后，正确率最低的模块才算弱项。
    expect(
      weakestModule([stat('数量关系', 10, 6), stat('言语理解', 40, 34)])?.module,
      '数量关系',
    );
  });
}
