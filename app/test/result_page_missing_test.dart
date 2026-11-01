// 结果页的两个用户可见问题：
// 1) 题库换版后旧题全部失效时，页面说“这次练习全部答对”；
// 2) 已答/答对与模考得分率的分母只数“题库里还存在的题”，
//    少几道题就等于凭空多得分（明明 1/2 会显示 100%）。
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

/// 题库换版后旧题都找不到：questionsByIds 返回空。
class _EmptyContentRepository extends SeedContentRepository {
  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) => const [];

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};
}

/// 只认得一半题：模拟题库更新后部分旧题消失。
class _PartialContentRepository extends SeedContentRepository {
  _PartialContentRepository(this.known);

  final List<QuestionContent> known;

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    final byId = {for (final question in known) question.id: question};
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

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpResult(
    WidgetTester tester,
    String sessionId,
    ContentRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  List<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .toList();

  testWidgets('题库换版后题目全部失效：不能谎报“这次练习全部答对”', (tester) async {
    final questions = [_question('gone-1'), _question('gone-2')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-gone',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 2,
      );
      await database.saveAnswer(
        sessionId: 'session-gone',
        questionId: 'gone-1',
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 1000,
      );
      await database.finalizeSession(
        sessionId: 'session-gone',
        questionLookup: {for (final q in questions) q.id: q},
      );
    });

    await pumpResult(tester, 'session-gone', _EmptyContentRepository());
    final all = texts(tester);
    expect(all.any((text) => text.contains('全部答对')), isFalse);
    expect(all.any((text) => text.contains('题目已随题库更新失效')), isTrue);
  });

  testWidgets('部分题目失效时，已答/答对不能跟着变少', (tester) async {
    final questions = [
      _question('keep-1'),
      _question('gone-1'),
      _question('gone-2'),
    ];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-partial',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 3,
        timeLimitSeconds: 7200,
      );
      for (final question in questions) {
        await database.saveAnswer(
          sessionId: 'session-partial',
          questionId: question.id,
          selected: {'A'},
          submitted: true,
          isCorrect: true,
          durationMs: 1000,
        );
      }
      await database.finalizeSession(
        sessionId: 'session-partial',
        questionLookup: {for (final q in questions) q.id: q},
      );
    });

    await pumpResult(
      tester,
      'session-partial',
      _PartialContentRepository([questions.first]),
    );
    final all = texts(tester);
    // 3 题全答对，其中 2 题在新题库里找不到：
    // 已答必须是 3、答对必须是 3。早先两者都从“题库里还在的题”统计，
    // 这里会变成“已答 1 / 答对 1”。
    String? valueAfter(String label) {
      final index = all.indexOf(label);
      if (index < 0 || index + 1 >= all.length) return null;
      return all[index + 1];
    }

    expect(valueAfter('已答'), '3', reason: all.join(' | '));
    expect(valueAfter('答对'), '3', reason: all.join(' | '));
    expect(valueAfter('总题数'), '3', reason: all.join(' | '));
    // 模考分母是整卷题数：全部答对仍然是 100%。
    expect(all.contains('100'), isTrue, reason: all.join(' | '));
    // 但必须说明有题失效，不能默默少算。
    expect(all.any((text) => text.contains('失效')), isTrue);
  });

  testWidgets('模考中失效题算作未得分，不能因为分母变小而抬高得分率', (tester) async {
    final questions = [
      _question('keep-1'),
      _question('gone-1'),
      _question('gone-2'),
    ];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-mixed',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 3,
        timeLimitSeconds: 7200,
      );
      await database.saveAnswer(
        sessionId: 'session-mixed',
        questionId: 'keep-1',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 1000,
      );
      await database.saveAnswer(
        sessionId: 'session-mixed',
        questionId: 'gone-1',
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 1000,
      );
      await database.finalizeSession(
        sessionId: 'session-mixed',
        questionLookup: {for (final q in questions) q.id: q},
      );
    });

    await pumpResult(
      tester,
      'session-mixed',
      _PartialContentRepository([questions.first]),
    );
    final all = texts(tester);
    String? valueAfter(String label) {
      final index = all.indexOf(label);
      if (index < 0 || index + 1 >= all.length) return null;
      return all[index + 1];
    }

    expect(valueAfter('已答'), '2', reason: all.join(' | '));
    expect(valueAfter('答对'), '1', reason: all.join(' | '));
    // 1 / 3 = 33%，而不是 1 / 1 = 100%。
    expect(all.contains('33'), isTrue, reason: all.join(' | '));
  });
}
