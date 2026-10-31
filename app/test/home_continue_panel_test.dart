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

/// 首页「继续练习」面板：位置和已答数量是两回事。
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('只答 1 题却翻到最后一题时，面板同时显示位置和真实已答数量', (tester) async {
    final questions = [
      for (var i = 1; i <= 5; i++)
        QuestionContent(
          id: 'q$i',
          paperId: 'p',
          questionNo: i,
          sequence: i,
          module: '言语理解',
          stem: '题干$i',
          options: const {'A': '甲', 'B': '乙'},
          correctAnswers: const {'A'},
          solution: '解析',
        ),
    ];
    await tester.runAsync(() async {
      await database.createSession(
        id: 's-home',
        mode: PracticeMode.custom,
        title: '五题',
        questions: questions,
        revealMode: RevealMode.immediate,
      );
      await database.saveAnswer(
        sessionId: 's-home',
        questionId: 'q1',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 1000,
      );
      await database.saveProgress(
        sessionId: 's-home',
        currentIndex: 4,
        durationMs: 2000,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _EmptyContentRepository(),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    // FutureProvider 要再跑一轮真实时间才能拿到已答数量：
    // 只 pump 一次会停在「正在读取已答数量…」。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .toList();
    // 位置：停在最后一题。
    expect(texts.any((text) => text.contains('上次练到第 5 / 5 题')), isTrue);
    // 真实进度：只答了 1 题，还剩 4 题。早先面板完全没有这一行。
    expect(
      texts.any((text) => text.contains('已答 1 题，还剩 4 题')),
      isTrue,
      reason: '面板必须显示真实已答数量，否则用户以为练完了',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
