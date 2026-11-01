// 题库页的「题目 / 收藏 / 笔记」列表以前整行不可点：
// 只有右上角的书签/删除按钮能点，想打开某一道题看解析或自己写的笔记，
// 只能把整组（可能是 200 道）变成一次练习再翻到它。
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
import 'package:kuangshuati/features/bank/bank_page.dart';

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
  List<QuestionContent> searchQuestions(String query, {int limit = 200}) {
    final needle = query.trim().toLowerCase();
    return questions
        .where((question) => question.plainStem.toLowerCase().contains(needle))
        .take(limit)
        .toList();
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
  stem: '基层治理的那道题 $id',
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
  final questions = [_question('q-1'), _question('q-2')];

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpBank(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
          home: const Scaffold(body: BankPage()),
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('题目搜索结果可以整行点开', (tester) async {
    await pumpBank(tester);
    await tester.tap(find.text('题目'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '基层治理');
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where((tile) => '${tile.title is Text ? (tile.title as Text).data : ''}'
            .contains('基层治理'))
        .toList();
    expect(tiles, isNotEmpty, reason: '应该搜到题目');
    expect(tiles.first.onTap, isNotNull, reason: '搜索结果整行应可点开');

    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 50);
    // 冲掉 InkWell/进度指示器残留的定时器，否则断言 !timersPending 会失败。
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('收藏列表可以整行点开', (tester) async {
    await tester.runAsync(() async {
      for (final question in questions) {
        await database.toggleFavorite(question.id);
        await database.setFavoriteNote(question.id, '我的笔记');
      }
    });
    await pumpBank(tester);
    await tester.tap(find.text('收藏'));
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, isNotEmpty);
    expect(
      tiles.every((tile) => tile.onTap != null),
      isTrue,
      reason: '收藏行整行应可点开',
    );

    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 50);
    // 冲掉 InkWell/进度指示器残留的定时器，否则断言 !timersPending 会失败。
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  });
}
