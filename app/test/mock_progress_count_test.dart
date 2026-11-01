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
import 'package:kuangshuati/features/home/home_page.dart';

class _EmptyContentRepository extends SeedContentRepository {
  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) => const [];

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

/// 首页「继续练习」的已答数必须按“选过选项”算。
///
/// 模考和「关闭立即出答案」模式下，练习页每选一个选项就落库一次，
/// 但 submitted 要等交卷才置 true。早先首页只数 submitted = true 的行，
/// 结果模考答了 3 题退出，首页仍然写「这一组还没有提交答案」。
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('模考答了 3 题后退出，首页显示已答 3 题', (tester) async {
    final questions = [for (var i = 0; i < 5; i++) _question('q$i')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'mock-1',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 5,
        timeLimitSeconds: 7200,
      );
      for (final question in questions.take(3)) {
        await database.saveAnswer(
          sessionId: 'mock-1',
          questionId: question.id,
          selected: {'B'},
          submitted: false,
          isCorrect: null,
          durationMs: 4000,
          module: question.module,
        );
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(_EmptyContentRepository()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    // 两个 Provider 都要跑一轮真实时间：先等会话，再等已答数量。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .toList();
    expect(
      texts.any((text) => text.contains('已答 3 题，还剩 2 题')),
      isTrue,
      reason: texts.join(' | '),
    );
    expect(
      texts.any((text) => text.contains('这一组还没有提交答案')),
      isFalse,
      reason: '模考已经答了 3 题，不能说“还没有提交答案”',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('模考答了 3 题后，弹「结束旧练习？」时也显示 3 题', (tester) async {
    final questions = [for (var i = 0; i < 5; i++) _question('q$i')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'mock-2',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 5,
      );
      for (final question in questions.take(3)) {
        await database.saveAnswer(
          sessionId: 'mock-2',
          questionId: question.id,
          selected: {'B'},
          submitted: false,
          isCorrect: null,
          durationMs: 4000,
          module: question.module,
        );
      }
    });
    expect(await database.submittedCountFor('mock-2'), 3);
  });
}
