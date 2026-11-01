// 结果页文案核对：标了「不确定」但没作答的题，是否真的进了明天的复习计划。
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
  module: '数量关系',
  stem: '题干 $id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('标了不确定但没作答：不能谎称“已加入明天的复习计划”', (tester) async {
    final questions = [_question('u-1'), _question('u-2')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-uncertain-blank',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: questions,
        revealMode: RevealMode.immediate,
      );
      // 第 1 题答对并标记不确定；第 2 题只标记不确定、根本没选答案。
      await database.saveAnswer(
        sessionId: 'session-uncertain-blank',
        questionId: 'u-1',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 1000,
        uncertain: true,
      );
      await database.saveAnswer(
        sessionId: 'session-uncertain-blank',
        questionId: 'u-2',
        selected: {},
        submitted: false,
        isCorrect: null,
        durationMs: 1000,
        uncertain: true,
      );
      await database.finalizeSession(
        sessionId: 'session-uncertain-blank',
        questionLookup: {for (final q in questions) q.id: q},
      );
    });

    final review = await database.allReviewItems();
    // 只有第 1 题进了复习；第 2 题（未作答）没有。
    expect(review.map((item) => item.questionId).toList(), ['u-1']);

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          home: const ResultPage(sessionId: 'session-uncertain-blank'),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .toList();
    // ignore: avoid_print
    print('UNCERTAIN_TEXTS ${texts.join(" | ")}');
    // 界面上写的是「本次有 2 道题被标记不确定，已加入明天的复习计划」，
    // 但实际只有 1 道进了复习计划。
    expect(
      texts.any((text) => text.contains('已加入明天的复习计划')),
      isTrue,
    );
    expect(
      texts.any((text) => text.contains('2 道题被标记不确定')),
      isFalse,
      reason: '未作答的题不会进复习计划，不能说“已加入”',
    );
  });
}
