// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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

/// 1×1 PNG，用于验证题图渲染分支。
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '/A8AAusB9Y9Z4WQAAAAASUVORK5CYII=',
);

/// 可声明每张图原始高度的仓储子类，用来驱动行内/块级分流。
class _SizedContentRepository extends SeedContentRepository {
  _SizedContentRepository(this.heights, {this.missing = const <String>{}});

  final Map<String, int> heights;

  /// 声明了高度但实际取不到字节，用来验证缺图占位。
  final Set<String> missing;

  @override
  Map<String, int> imageHeightsSync(Iterable<String> assetIds) => {
    for (final id in assetIds)
      if (heights.containsKey(id)) id: heights[id]!,
  };

  @override
  Future<repo.ContentImage?> imageWithSize(String assetId) async {
    final height = heights[assetId];
    if (height == null || missing.contains(assetId)) return null;
    return repo.ContentImage(bytes: _pngBytes, width: height, height: height);
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
    expect(find.bySemanticsLabel('查看题图'), findsOneWidget);
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
}
