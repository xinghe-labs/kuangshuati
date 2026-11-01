// 统计页「最近练习」的成绩口径必须和结果页一致：
// 模考看得分率（分母=整卷题数，未答按 0 分），练习看正确率（分母=已答题数）。
// 以前列表统一写“正确率”，一场 100 题只答 50 题的模考，
// 列表显示“50/100 题 · 正确率 80%”，点进去结果页却是 40%。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/stats/stats_page.dart';

class _EmptyContentRepository extends SeedContentRepository {
  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) => const [];

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};
}

QuestionContent _question(int index) => QuestionContent(
  id: 'q-$index',
  paperId: 'paper-1',
  questionNo: index,
  sequence: index,
  module: '判断推理',
  stem: '题干 $index',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

Future<void> _settle(WidgetTester tester, [int ms = 350]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('模考在最近练习里显示得分率而不是正确率', (tester) async {
    final questions = [for (var i = 1; i <= 10; i++) _question(i)];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'mock-1',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 10,
        timeLimitSeconds: 7200,
      );
      // 只答 5 题，其中 4 题对（第 5 题故意选 B 选错）。
      for (var i = 1; i <= 5; i++) {
        await database.saveAnswer(
          sessionId: 'mock-1',
          questionId: 'q-$i',
          selected: {i == 5 ? 'B' : 'A'},
          submitted: true,
          isCorrect: i != 5,
          durationMs: 1000,
        );
      }
      await database.finalizeSession(
        sessionId: 'mock-1',
        questionLookup: {for (final question in questions) question.id: question},
      );
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _EmptyContentRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: StatsPage()),
        ),
      ),
    );
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList();
    final subtitle = texts.firstWhere(
      (text) => text.contains('/10 题'),
      orElse: () => '',
    );
    // ignore: avoid_print
    print('RECENT_SUBTITLE $subtitle');
    expect(subtitle, contains('得分率'));
    // 4 对 / 10 题整卷 = 40%，而不是 4/5 = 80%。
    expect(subtitle, contains('40%'));

    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 50);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('未交卷的练习在最近练习里不显示正确率', (tester) async {
    final questions = [_question(1), _question(2)];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'abandoned-1',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 2,
      );
      for (final question in questions) {
        await database.saveAnswer(
          sessionId: 'abandoned-1',
          questionId: question.id,
          selected: {'A'},
          submitted: false,
          isCorrect: null,
          durationMs: 1000,
          module: question.module,
        );
      }
      // 开另一组，把这组挤成 abandoned。
      await database.createSession(
        id: 'active-1',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [questions.first],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
    });

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _EmptyContentRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: StatsPage()),
        ),
      ),
    );
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList();
    final subtitle = texts.firstWhere(
      (text) => text.contains('/2 题'),
      orElse: () => '',
    );
    // ignore: avoid_print
    print('ABANDONED_SUBTITLE $subtitle');
    // 用户只是没做完就退出，列表不能写“正确率 0%”。
    expect(subtitle, contains('未交卷'));
    expect(subtitle, isNot(contains('正确率')));

    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 50);
    await tester.pump(const Duration(seconds: 1));
  });
}
