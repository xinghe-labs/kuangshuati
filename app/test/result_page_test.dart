import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/result/result_page.dart';

void main() {
  final repository = SeedContentRepository();
  final questions = repository.allQuestions.take(4).toList();
  final lookup = {for (final question in questions) question.id: question};

  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  /// 建一场已交卷的练习：前两道作答（一对一错），剩下的不答。
  Future<String> seedSession(PracticeMode mode) async {
    await database.createSession(
      id: 'session-${mode.name}',
      mode: mode,
      title: mode.label,
      questions: questions,
      revealMode: mode == PracticeMode.mock
          ? RevealMode.afterSubmit
          : RevealMode.immediate,
      requestedCount: questions.length,
      timeLimitSeconds: mode == PracticeMode.mock ? 7200 : null,
    );
    await database.saveAnswer(
      sessionId: 'session-${mode.name}',
      questionId: questions[0].id,
      selected: questions[0].correctAnswers,
      submitted: true,
      isCorrect: true,
      durationMs: 1000,
    );
    final wrong = questions[1];
    await database.saveAnswer(
      sessionId: 'session-${mode.name}',
      questionId: wrong.id,
      selected: {'Z'},
      submitted: true,
      isCorrect: false,
      durationMs: 1000,
    );
    await database.finalizeSession(
      sessionId: 'session-${mode.name}',
      questionLookup: lookup,
    );
    return 'session-${mode.name}';
  }

  Future<void> pumpResult(WidgetTester tester, String sessionId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: ResultPage(sessionId: sessionId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('practice result uses answered questions as the denominator', (
    tester,
  ) async {
    final sessionId = await seedSession(PracticeMode.sequence);
    await pumpResult(tester, sessionId);

    // 4 道题只答了 2 道，答对 1 道：练习正确率 = 1/2 = 50%。
    expect(find.text('50'), findsOneWidget);
    expect(find.text('% 正确率'), findsOneWidget);
    expect(find.text('% 得分率'), findsNothing);
  });

  testWidgets('mock result uses the whole paper as the denominator', (
    tester,
  ) async {
    final sessionId = await seedSession(PracticeMode.mock);
    await pumpResult(tester, sessionId);

    // 同一份作答，模考得分率 = 1/4 = 25%，未答按零分。
    expect(find.text('25'), findsOneWidget);
    expect(find.text('% 得分率'), findsOneWidget);
    expect(find.text('% 正确率'), findsNothing);
  });

  testWidgets('result page separates wrong and unanswered questions', (
    tester,
  ) async {
    // 用一块够大的画布，避免结果页把过滤开关和逐题列表滚出可视区。
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionId = await seedSession(PracticeMode.mock);
    await pumpResult(tester, sessionId);

    // 默认展示“全部题目”，点一下切到“仅看错题”视图。
    await tester.tap(find.text('全部题目'));
    await tester.pumpAndSettle();
    expect(find.text('仅看错题'), findsOneWidget);

    // 只答错 1 道，另有 2 道未答：两种状态必须分别标明，不能混成一个“错题”。
    expect(find.textContaining('错误 · 你的答案 Z'), findsOneWidget);
    expect(find.textContaining('未作答 ·'), findsWidgets);
  });
}
