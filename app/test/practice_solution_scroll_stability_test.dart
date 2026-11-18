// 解析过长时，滑到底部再往上滑会被反复弹回底部（用户反馈「无限回弹鬼畜」）。
//
// 机制：解析里的公式图先按块级占位画（160×72），资产高度异步查到后再改判行内
// （28px），每张图让内容矮约 50px。用户停在底部时，ListView 会把 pixels clamp 到
// 变短的 maxScrollExtent —— 观感就是「往上滑又被拽回底部」。解析越长、公式图越多，
// 拽回的距离越大；被回收的 RichContent 重新挂载又会重来一遍，于是看起来没有尽头。
//
// 修复：进页面前把整题（材料/题干/选项/解析）的图高一次查好，通过
// RichContent.heightMap 传下去，首帧就是最终排版；高度还由调用方持有，
// 列表回收后重新挂载也不会再查一次、再缩一次。
//
// 核心不变量：**解析第一次可见的那一帧，内容高度就必须是最终高度**。
// 那一帧里 RichContent 自己发起的异步查询不可能已经返回，所以修复前
// 必然是「块级占位（高）→ 查到后收缩（矮）」，这个断言一定会失败。
//
// 注意：练习页有每秒 tick 的定时器，`pumpAndSettle` 永远不会停下来，
// 所以这里用精确的 `pump` 步进。
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
import 'package:kuangshuati/features/practice/practice_page.dart';

/// 记录 `imageHeights` 被调用了几次：一次是页面预查，多出来的就说明
/// 还有 RichContent 在自己异步查（那正是收缩的来源）。
class _RecordingContentRepository extends SeedContentRepository {
  _RecordingContentRepository(this.questions);

  final List<QuestionContent> questions;
  int heightCalls = 0;
  final List<int> heightsAsked = [];

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
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async {
    heightCalls++;
    final ids = assetIds.toList();
    heightsAsked.add(ids.length);
    // 公式图 28px（行内），题图 180px（块级）。
    return {
      for (final id in ids) id: id.startsWith('block-') ? 180 : 28,
    };
  }
}

/// 一段很长的解析：每步两张行内公式图，重复 [steps] 次。
String _longSolution(int steps) {
  final buffer = StringBuffer('解析：本题按以下步骤推导。\n');
  for (var i = 0; i < steps; i++) {
    buffer.write(
      '第 ${i + 1} 步：设 \ue000f-$i\ue001 为已知量，代入 \ue000g-$i\ue001 '
      '计算，可得结论成立。\n',
    );
  }
  return buffer.toString();
}

QuestionContent _longSolutionQuestion({
  required String id,
  required int steps,
}) => QuestionContent(
  id: id,
  paperId: 'paper-1',
  questionNo: 1,
  sequence: 1,
  module: '数量关系',
  // 不含块级题图：块级图占位（160x72）要按可用宽度缩放才得到最终高度，
  // 不属于本次「公式图两段式」修复范围，这里排除掉，断言只测公式图。
  material: '材料：阅读下面的表格。',
  stem: '根据材料，下列结论正确的是 \ue000s-1\ue001 ？',
  options: const {'A': '选项甲', 'B': '选项乙 \ue000o-1\ue001'},
  correctAnswers: const {'A'},
  solution: _longSolution(steps),
  searchStem: null,
  groupId: '',
);

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> runMs(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// 拆页面并排空 fake 时钟：drift 的查询流在 ProviderScope 销毁时会
  /// 挂一个零时长 timer，不排空就会被判为「A Timer is still pending」。
  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> seedSession(QuestionContent question) async {
    await database.createSession(
      id: 'session-long',
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: [question],
      revealMode: RevealMode.immediate,
      requestedCount: 1,
    );
    // 已作答并提交：解析面板（最长的那段）一进页面就渲染出来。
    await database.saveAnswer(
      sessionId: 'session-long',
      questionId: question.id,
      selected: {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 3000,
    );
  }

  Future<void> pumpPractice(
    WidgetTester tester,
    ContentRepository repository,
  ) async {
    // 宽一点避免底部操作栏溢出，矮一点保证内容确实需要滚动。
    tester.view.physicalSize = const Size(1200, 900);
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
          home: const PracticePage(sessionId: 'session-long'),
        ),
      ),
    );
  }

  final listView = find.byType(ListView);
  final scrollable = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  /// 逐帧推进到「解析面板第一次出现」，返回那一帧的 maxScrollExtent。
  Future<double> maxWhenSolutionAppears(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() => runMs(5));
      await tester.pump();
      if (find.text('解析').evaluate().isNotEmpty) {
        return tester.state<ScrollableState>(scrollable).position
            .maxScrollExtent;
      }
    }
    fail('解析面板始终没有出现，这个测试没测到东西');
  }

  /// 放掉首帧之后所有可能的异步回调（修复前收缩就发生在这一步）。
  Future<void> settleAsync(WidgetTester tester, [int ms = 300]) async {
    await tester.runAsync(() => runMs(ms));
    await tester.pump();
    await tester.pump();
  }


  testWidgets('解析第一次可见时高度就是最终高度，停在底部不会被拽回', (tester) async {
    final question = _longSolutionQuestion(id: 'q-long', steps: 40);
    final repository = _RecordingContentRepository([question]);
    await tester.runAsync(() => seedSession(question));

    await pumpPractice(tester, repository);

    // 解析第一次出现的那一帧：内容高度应当已经是最终高度。
    final maxAtFirstSight = await maxWhenSolutionAppears(tester);
    expect(
      maxAtFirstSight,
      greaterThan(300),
      reason: '解析不够长就没法复现这个 bug',
    );

    await settleAsync(tester);
    final position = tester.state<ScrollableState>(scrollable).position;
    final settledMax = position.maxScrollExtent;

    expect(
      settledMax,
      moreOrLessEquals(maxAtFirstSight, epsilon: 0.5),
      reason: '解析先按块级占位（高）画出来，图高查到后又缩回去：'
          '停在底部时位置就会被 clamp，表现成「向上滑被弹回底部」',
    );

    // 只应有一次「整题预查」；多出来的调用说明还有组件在自己异步查高度。
    expect(
      repository.heightCalls,
      1,
      reason: '预查次数异常：材料/题干/选项/解析各自的 RichContent 又各自查了一遍',
    );
    expect(
      repository.heightsAsked.single,
      greaterThan(70),
      reason: '预查应当覆盖解析里全部公式图（40 步 × 2 张 + 题干/选项/题图）',
    );

    // 用户视角：停在底部往上滑，位移应当原样生效。
    position.jumpTo(settledMax);
    await tester.pump();
    final before = position.pixels;
    final gesture = await tester.startGesture(tester.getCenter(listView));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      before - position.pixels,
      moreOrLessEquals(160, epsilon: 1),
      reason: '向上滑 160px 只生效了一部分：途中被内容收缩拽回去了',
    );

    await disposePage(tester);
  });

  testWidgets('解析区被列表回收后重新挂载，首帧仍是最终高度、也不会再查一次', (tester) async {
    final question = _longSolutionQuestion(id: 'q-long', steps: 40);
    final repository = _RecordingContentRepository([question]);
    await tester.runAsync(() => seedSession(question));

    await pumpPractice(tester, repository);
    final maxAtFirstSight = await maxWhenSolutionAppears(tester);
    await settleAsync(tester);

    final position = tester.state<ScrollableState>(scrollable).position;
    final settledMax = position.maxScrollExtent;
    expect(settledMax, moreOrLessEquals(maxAtFirstSight, epsilon: 0.5));
    expect(repository.heightCalls, 1);

    // 滑到顶：解析区离开视口（超过 cacheExtent）会被 ListView 回收。
    position.jumpTo(0);
    await tester.pump();
    await tester.pump();

    // 再滑回底部：解析区重新挂载。这一帧的高度必须还是最终高度。
    position.jumpTo(settledMax);
    await tester.pump();
    final maxAtRemount = tester.state<ScrollableState>(scrollable).position
        .maxScrollExtent;

    await settleAsync(tester);
    final settledAfterRemount = tester.state<ScrollableState>(scrollable)
        .position
        .maxScrollExtent;

    expect(
      maxAtRemount,
      moreOrLessEquals(settledAfterRemount, epsilon: 0.5),
      reason: '重新挂载时又把公式图撑回块级占位：高度该由页面持有，'
          '不该随组件生命周期重来',
    );
    expect(
      repository.heightCalls,
      1,
      reason: '重新挂载又去查高度了',
    );

    await disposePage(tester);
  });
}
