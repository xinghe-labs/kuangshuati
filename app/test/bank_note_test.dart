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
  // 页面里有 stream → FutureBuilder 的多层异步，单次 pump 只能推进一层，
  // 必须多轮「等异步完成 + pump」才能拿到最终列表。
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms ~/ 5)),
    );
    await tester.pump();
  }
}

Future<void> _pumpBank(
  WidgetTester tester,
  AppDatabase database,
  List<QuestionContent> questions,
) async {
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
  await _settle(tester, 300);
}

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .toList();

/// 收尾：拆掉页面让 stream 订阅取消，再放行一帧把零延迟定时器跑完，
/// 否则 flutter_test 会报 “Timer is still pending”。
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

  testWidgets('收藏列表直接显示自己写的笔记，并且能按笔记内容搜到', (tester) async {
    final questions = [
      _question('f-1', '关于基层治理的说法，正确的是', 1),
      _question('f-2', '关于行政复议的说法，正确的是', 2),
    ];
    await tester.runAsync(() async {
      await database.toggleFavorite('f-1');
      await database.setFavoriteNote('f-1', '网格化是关键');
      await database.toggleFavorite('f-2');
    });

    await _pumpBank(tester, database, questions);
    await tester.tap(find.text('收藏'));
    await _settle(tester, 300);

    // 列表里直接能看到笔记，不用点进题目才能回看。
    expect(_texts(tester).any((text) => text.contains('网格化是关键')), isTrue);

    // 搜索框按笔记关键词要能命中（以前只搜题干）。
    await tester.enterText(find.byType(TextField), '网格化');
    await _settle(tester, 300);
    final texts = _texts(tester);
    expect(texts.any((text) => text.contains('基层治理')), isTrue);
    expect(texts.any((text) => text.contains('行政复议')), isFalse);

    // 搜不到时给出明确提示，而不是空白页。
    await tester.enterText(find.byType(TextField), '不存在的关键词');
    await _settle(tester, 300);
    expect(_texts(tester).any((text) => text.contains('没有匹配的收藏')), isTrue);

    await _teardown(tester);
  });

  testWidgets('在收藏列表里误点取消收藏，能靠提示里的「撤销」加回来', (tester) async {
    final questions = [_question('u-1', '关于基层治理的说法，正确的是', 1)];
    await tester.runAsync(() async {
      await database.toggleFavorite('u-1');
      await database.setFavoriteNote('u-1', '别丢我');
    });

    await _pumpBank(tester, database, questions);
    await tester.tap(find.text('收藏'));
    await _settle(tester, 300);
    expect(_texts(tester).any((text) => text.contains('基层治理')), isTrue);

    // 书签图标就在标题右侧，很容易误触。
    await tester.tap(find.byTooltip('取消收藏'));
    await _settle(tester, 300);
    // SnackBar 有入场动画，动画期间外层是 IgnorePointer，必须等它稳定。
    await tester.pump(const Duration(milliseconds: 800));
    expect(await database.isFavorite('u-1'), isFalse);
    // 取消收藏后必须给提示，并带上撤销入口。
    expect(_texts(tester).any((text) => text.contains('已取消收藏')), isTrue);
    expect(find.text('撤销'), findsOneWidget);

    await tester.tap(find.text('撤销'));
    await _settle(tester, 300);
    expect(await database.isFavorite('u-1'), isTrue);
    // 笔记不能跟着丢。
    expect(await database.favoriteNote('u-1'), '别丢我');

    await _teardown(tester);
  });

  testWidgets('删除笔记前会先确认，取消后笔记仍然在', (tester) async {
    final questions = [_question('n-1', '关于基层治理的说法，正确的是', 1)];
    await tester.runAsync(() async {
      await database.toggleFavorite('n-1');
      await database.setFavoriteNote('n-1', '别删我');
    });

    await _pumpBank(tester, database, questions);
    await tester.tap(find.text('笔记'));
    await _settle(tester, 300);
    expect(_texts(tester).any((text) => text.contains('别删我')), isTrue);

    await tester.tap(find.byTooltip('删除笔记'));
    await _settle(tester, 300);
    expect(find.text('删除这条笔记？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await _settle(tester, 300);

    expect(await database.favoriteNote('n-1'), '别删我');
    expect(_texts(tester).any((text) => text.contains('别删我')), isTrue);

    // 确认删除才真的删。
    await tester.tap(find.byTooltip('删除笔记'));
    await _settle(tester, 300);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await _settle(tester, 300);
    expect(await database.favoriteNote('n-1'), isEmpty);

    await _teardown(tester);
  });
}
