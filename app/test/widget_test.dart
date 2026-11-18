// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart' as repo;
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/shared/widgets/app_widgets.dart';
import 'package:kuangshuati/shared/widgets/rich_content.dart';

/// 合法的 100×28 PNG，用于验证题图渲染分支。
///
/// 之前这里用的是 base64 硬编码的 1×1 PNG，Flutter 的 codec 解不了
/// （`Codec failed to produce an image`，PIL 能读但 Flutter 不能），
/// `Image` 于是退化成 `_debugBuildErrorWidget` 的全宽 Stack——
/// 块级图因为外面套了固定盒子看不出来，行内图会被量成整行宽，直接量错。
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAGQAAAAcCAIAAAAY8Y2vAAAAH0lEQVR4nO3B'
  'AQ0AAADCoPdPbQ43oAAAAAAAAAAAujEg7AABFmN43gAAAABJRU5ErkJggg==',
);

/// 可声明每张图原始高度的仓储子类，用来驱动行内/块级分流。
class _SizedContentRepository extends SeedContentRepository {
  _SizedContentRepository(
    this.heights, {
    this.missing = const <String>{},
    this.hang = false,
    this.dims = const <String, repo.AssetSize>{},
  });

  final Map<String, int> heights;

  /// 声明了高度但实际取不到字节，用来验证缺图占位。
  final Set<String> missing;

  /// true = `imageWithSize` 永不返回，把组件钉在「占位」状态。
  final bool hang;

  /// 需要非方形素材时显式指定原始宽高。
  final Map<String, repo.AssetSize> dims;

  @override
  Future<Map<String, repo.AssetSize>> imageSizes(
    Iterable<String> assetIds,
  ) async => {
    // 没显式指定宽高时按正方形处理（与下面的 imageWithSize 对齐）。
    for (final id in assetIds)
      if (dims.containsKey(id))
        id: dims[id]!
      else if (heights.containsKey(id))
        id: repo.AssetSize(heights[id]!, heights[id]!),
  };

  @override
  Future<repo.ContentImage?> imageWithSize(String assetId) {
    if (hang) return Completer<repo.ContentImage?>().future;
    final size = dims[assetId];
    final height = size?.height ?? heights[assetId];
    if (height == null || missing.contains(assetId)) {
      return Future.value(null);
    }
    return Future.value(
      repo.ContentImage(
        bytes: _pngBytes,
        width: size?.width ?? height,
        height: height,
      ),
    );
  }
}

Future<void> _pumpRichContent(
  WidgetTester tester,
  String markup,
  Map<String, int> heights, {
  Set<String> missing = const <String>{},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        contentRepositoryProvider.overrideWithValue(
          _SizedContentRepository(heights, missing: missing),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: RichContent(markup)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 统计所有 SelectableText 内联的 WidgetSpan 个数（行内图就靠它占位）。
int _inlineImageSpanCount(WidgetTester tester) {
  var count = 0;
  for (final element in find.byType(SelectableText).evaluate()) {
    final textSpan = (element.widget as SelectableText).textSpan;
    if (textSpan is! TextSpan) continue;
    for (final child in textSpan.children ?? const <InlineSpan>[]) {
      if (child is WidgetSpan) count++;
    }
  }
  return count;
}

void main() {
  testWidgets('shared tags render with the product theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: AppEmptyState(title: '暂无记录', message: '开始一组练习'),
        ),
      ),
    );

    expect(find.text('暂无记录'), findsOneWidget);
    expect(find.text('开始一组练习'), findsOneWidget);
  });

  testWidgets('rich content keeps text and inline image in one text flow', (
    tester,
  ) async {
    await _pumpRichContent(tester, '前文\ue000asset-1\ue001后文', {'asset-1': 20});

    // 关键回归：文字与行内图必须在同一个 TextSpan 流里，否则公式图会独占一行。
    expect(find.byType(SelectableText), findsOneWidget);
    expect(_inlineImageSpanCount(tester), 1);
    expect(find.byType(Image), findsOneWidget);
    // 行内公式图不能做成可点按钮：答题页滑动时手指落在公式上会弹出
    // 全屏查看，把正在作答的用户打断。只有块级题图才可点放大。
    expect(find.bySemanticsLabel('查看题图'), findsNothing);
  });

  testWidgets('sandwiched two-line formula stays inline below context cap', (
    tester,
  ) async {
    // 45 > 行内阈值 40，但夹在句中 → 仍按行内，避免把句子切断。
    await _pumpRichContent(tester, '约等于\ue000asset-2\ue001，则可知', {
      'asset-2': 45,
    });

    expect(find.byType(SelectableText), findsOneWidget);
    expect(_inlineImageSpanCount(tester), 1);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('tall image renders as a block between paragraphs', (
    tester,
  ) async {
    await _pumpRichContent(tester, '前文\ue000asset-3\ue001后文', {'asset-3': 300});

    // 块级图不在文字流里：没有 WidgetSpan，前后文字各自成段。
    expect(_inlineImageSpanCount(tester), 0);
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('oversized sandwiched image stays block level', (tester) async {
    // 100 夹在句中但超过句中上限 72 → 仍按块级，不拉乱行距。
    await _pumpRichContent(tester, '前文\ue000asset-4\ue001后文', {'asset-4': 100});

    expect(_inlineImageSpanCount(tester), 0);
    expect(find.byType(SelectableText), findsNWidgets(2));
  });

  testWidgets('missing inline asset keeps the text flow intact', (
    tester,
  ) async {
    await _pumpRichContent(
      tester,
      '前文\ue000asset-5\ue001后文',
      {'asset-5': 20},
      missing: {'asset-5'},
    );

    // 缺图也要等高空位，文字流不塔。
    expect(find.byType(SelectableText), findsOneWidget);
    expect(_inlineImageSpanCount(tester), 1);
    expect(find.byType(Image), findsNothing);
  });

  /// 把 RichContent 放进 400 宽的内容区，返回首帧与加载完成后的高度。
  Future<({double firstFrame, double settled})> blockImageHeights(
    WidgetTester tester, {
    required repo.AssetSize size,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            _SizedContentRepository({'asset-block': size.height}),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: SizedBox(
                width: 400,
                child: RichContent(
                  '\ue000asset-block\ue001',
                  imageSizes: {'asset-block': size},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 只有一张块级图，Wrap 的高度就是这张图的占位/渲染高度。
    final firstFrame = tester.getSize(find.byType(Wrap)).height;
    await tester.pumpAndSettle();
    return (
      firstFrame: firstFrame,
      settled: tester.getSize(find.byType(Wrap)).height,
    );
  }

  testWidgets('block image reserves its final box on the very first frame', (
    tester,
  ) async {
    // 原始 600×300 的题图放在 400 宽的内容区：最终渲染 400×200。
    // 首帧（字节还没到）就应该占住这个盒子——否则图加载完会把下方内容顶走，
    // 用户停在底部时滚动位置就会被 clamp，表现为「往上滑被弹回」。
    final heights = await blockImageHeights(
      tester,
      size: const repo.AssetSize(600, 300),
    );

    expect(
      heights.settled,
      moreOrLessEquals(heights.firstFrame, epsilon: 0.5),
      reason: '首帧占位（旧实现固定 160×72）和加载完成后的尺寸不一致',
    );
    // 400×200 + 上下各 4px 内边距 = 208。
    expect(heights.settled, moreOrLessEquals(208, epsilon: 0.5));
  });

  testWidgets('block image is not upscaled beyond its natural size', (
    tester,
  ) async {
    // 100×50 的小图不该被拉成 400 宽（旧实现 Image 无宽高，靠约束自己缩，
    // 新实现用算好的盒子，必须保持「不放大」这个行为）。
    final heights = await blockImageHeights(
      tester,
      size: const repo.AssetSize(100, 50),
    );

    expect(heights.settled, moreOrLessEquals(heights.firstFrame, epsilon: 0.5));
    // 50 + 8 = 58
    expect(heights.settled, moreOrLessEquals(58, epsilon: 0.5));
  });

  testWidgets('block image height is capped at 380 and keeps its ratio', (
    tester,
  ) async {
    // 300×1200 的窄高图：按 400 宽渲染会是 1600 高，必须封顶到 380。
    final heights = await blockImageHeights(
      tester,
      size: const repo.AssetSize(300, 1200),
    );

    expect(heights.settled, moreOrLessEquals(heights.firstFrame, epsilon: 0.5));
    // 380 + 8 = 388
    expect(heights.settled, moreOrLessEquals(388, epsilon: 0.5));
  });

  testWidgets('inline image placeholder matches the real image box', (
    tester,
  ) async {
    // 行内图真图宽度 = 字号缩放后的高度 × 原始宽高比。题库里公式图的宽高比
    // 实测 0.17–34.8（中位数 3.76），占位若固定按 1.4 猜，换成真图就会改变
    // 换行位置，整段高度跟着变——用户停在解析底部时同样被 clamp 拽回。
    //
    // 一行放多张图才能让「宽度猜错」真的改变换行：单张图在宽内容区里
    // 无论宽窄都只占一行，高度不变，断言就形同虚设（实测过：把修复回退成
    // 固定 1.4 倍，单图版本照样通过）。
    const dims = {
      'w-a': repo.AssetSize(105, 28), // 3.75
      'w-b': repo.AssetSize(236, 28), // 8.4
      'w-c': repo.AssetSize(66, 28), // 2.4
    };
    // PUA 标记用 charCode 拼，避免源码里出现转义序列被工具层吃掉。
    final open = String.fromCharCode(0xE000);
    final close = String.fromCharCode(0xE001);
    String img(String id) => '$open$id$close';
    final markup =
        '设 ${img('w-a')} 与 ${img('w-b')} 均为已知量，代入 ${img('w-c')} '
        '计算可得第一步结论。新的一行 '
        '设 ${img('w-a')} 与 ${img('w-b')} 均为已知量，代入 ${img('w-c')} '
        '计算可得第二步结论。';

    Future<double> heightWith({required bool hang}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRepositoryProvider.overrideWithValue(
              _SizedContentRepository(
                const {'w-a': 28, 'w-b': 28, 'w-c': 28},
                hang: hang,
                dims: dims,
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: SizedBox(
                  width: 360,
                  // 必须用 mainAxisSize.min 包一层：RichContent 内部的 Column
                  // 默认撑满可用高度，直接量它会得到视口高度（实测 600），
                  // 内容高度怎么变都量不出来，断言形同虚设。
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichContent(
                        markup,
                        imageSizes: dims,
                        key: UniqueKey(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump();
      }
      if (!hang) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump();
        }
      }
      return tester.getSize(find.byType(RichContent)).height;
    }

    final placeholder = await heightWith(hang: true);
    final real = await heightWith(hang: false);

    expect(
      real,
      moreOrLessEquals(placeholder, epsilon: 0.5),
      reason: '行内图占位宽度猜错（固定 1.4 倍）→ 真图到位后换行位置变 → '
          '整段高度变 → 停在底部时滚动位置被 clamp',
    );
  });
}
