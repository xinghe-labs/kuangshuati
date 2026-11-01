// 回归：没交卷就被结束的练习不能冒充成绩（0% 正确率 / 全错标记）。
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
import 'package:kuangshuati/features/result/result_page.dart';

class _StubContentRepository extends SeedContentRepository {
  _StubContentRepository(this.questions);

  final List<QuestionContent> questions;

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    final byId = {for (final question in questions) question.id: question};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};
}

QuestionContent _question(String id) => QuestionContent(
  id: id,
  paperId: 'paper-1',
  questionNo: 1,
  sequence: 1,
  module: '判断推理',
  stem: '题干 $id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

Future<void> _settle(WidgetTester tester, [int ms = 200]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('没交卷的练习：不显示 0% 正确率，逐题回顾不标“错误”', (tester) async {
    final questions = [_question('q1'), _question('q2')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'abandoned',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 2,
      );
      for (final question in questions) {
        await database.saveAnswer(
          sessionId: 'abandoned',
          questionId: question.id,
          selected: {'A'},
          submitted: false,
          isCorrect: null,
          durationMs: 1000,
          module: question.module,
        );
      }
      // 开另一组练习会把上面这组挤成 abandoned（同一时间只留一组 active）。
      await database.createSession(
        id: 'next',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [questions.first],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _StubContentRepository(questions),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const ResultPage(sessionId: 'abandoned'),
        ),
      ),
    );
    await _settle(tester, 350);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .toList();
    // ignore: avoid_print
    print('RESULT ${texts.join(" | ")}');

    expect(texts.any((text) => text.contains('没有交卷')), isTrue);
    expect(texts.any((text) => text.contains('未判分')), isTrue);
    // 关键：不能出现“错误”这种判决，也不能把 0% 当成正确率。
    expect(texts.any((text) => text.contains('错误')), isFalse);
    expect(texts.contains('--'), isTrue, reason: '得分位置应显示占位符');
    expect(
      texts.any((text) => text.contains('正确率（未判分）')),
      isTrue,
      reason: '未判分时要说明，而不是写 0% 正确率',
    );
    // 已答仍要如实显示 2。
    final answeredIndex = texts.indexOf('已答');
    expect(answeredIndex, greaterThanOrEqualTo(0));
    expect(texts[answeredIndex + 1], '2');
  });

  test('summarizeSession 的 gradedCount 不把未判分答案算成答错', () async {
    final questions = [_question('q1'), _question('q2')];
    await database.createSession(
      id: 'abandoned',
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: questions,
      revealMode: RevealMode.immediate,
      requestedCount: 2,
    );
    await database.saveAnswer(
      sessionId: 'abandoned',
      questionId: 'q1',
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 1000,
      module: questions.first.module,
    );
    // 开另一组练习会把上面这组挤成 abandoned。
    await database.createSession(
      id: 'next',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: [questions.first],
      revealMode: RevealMode.immediate,
      requestedCount: 1,
    );

    final summary = await database.summarizeSession('abandoned');
    expect(summary.answeredCount, 1);
    expect(summary.correctCount, 0);
    expect(summary.gradedCount, 0);
    // 0 道判过分的题 → 正确率占位 0，而不是被算成“答了 1 题错 1 题”。
    expect(summary.scorePercent, 0);
  });
}
