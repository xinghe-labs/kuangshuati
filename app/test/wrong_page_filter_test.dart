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
import 'package:kuangshuati/features/wrong/wrong_page.dart';

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

QuestionContent _question(String id, String stem, int sequence) =>
    QuestionContent(
      id: id,
      paperId: 'paper-1',
      questionNo: sequence,
      sequence: sequence,
      module: '判断推理',
      stem: stem,
      options: const {'A': '甲', 'B': '乙'},
      correctAnswers: const {'A'},
      solution: '解析',
      searchStem: null,
      groupId: '',
    );

Future<void> _settle(WidgetTester tester, [int ms = 250]) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms ~/ 5)),
    );
    // 必须带时长 pump，否则弹出菜单/对话框的动画不会推进，
    // 菜单项还包在 AbsorbPointer 里，点击会落空。
    await tester.pump(const Duration(milliseconds: 120));
  }
}

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .toList();

Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('错题页有「全部」筛选：已掌握的题不用来回切菜单也能看到', (tester) async {
    final questions = [
      _question('w-1', '待复习的题', 1),
      _question('w-2', '已掌握的题', 2),
    ];
    await tester.runAsync(() async {
      final sessionId = 'session-w';
      await database.createSession(
        id: sessionId,
        mode: PracticeMode.custom,
        title: '测试',
        questions: questions,
        revealMode: RevealMode.immediate,
      );
      for (final question in questions) {
        await database.saveAnswer(
          sessionId: sessionId,
          questionId: question.id,
          selected: {'B'},
          submitted: true,
          isCorrect: false,
          durationMs: 1000,
        );
      }
      await database.finalizeSession(
        sessionId: sessionId,
        questionLookup: {for (final q in questions) q.id: q},
      );
      await database.markReviewMastered('w-2', true);
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
          home: const Scaffold(body: WrongPage()),
        ),
      ),
    );
    await _settle(tester, 400);

    // 默认「待复习」：只看得到未掌握的那道。
    expect(_texts(tester).any((text) => text.contains('待复习的题')), isTrue);
    expect(_texts(tester).any((text) => text.contains('已掌握的题')), isFalse);

    // 切到「全部」：两道都在，而且仍然显示到期提醒。
    await tester.tap(find.byTooltip('筛选错题'));
    await _settle(tester, 300);
    await tester.tap(find.text('全部').last);
    await _settle(tester, 400);
    final allTexts = _texts(tester);
    expect(allTexts.any((text) => text.contains('待复习的题')), isTrue);
    expect(allTexts.any((text) => text.contains('已掌握的题')), isTrue);

    // 切到「已掌握」：只剩已掌握的那道，且不再显示到期提醒条。
    await tester.tap(find.byTooltip('筛选错题'));
    await _settle(tester, 300);
    await tester.tap(find.text('已掌握').last);
    await _settle(tester, 400);
    final masteredTexts = _texts(tester);
    expect(masteredTexts.any((text) => text.contains('待复习的题')), isFalse);
    expect(masteredTexts.any((text) => text.contains('已掌握的题')), isTrue);
    expect(masteredTexts.any((text) => text.contains('道到期')), isFalse);

    await _teardown(tester);
  });
}
