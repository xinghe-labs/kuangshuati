// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/shared/widgets/app_widgets.dart';
import 'package:kuangshuati/shared/widgets/rich_content.dart';

class _ImageContentRepository extends SeedContentRepository {
  @override
  Uint8List? imageBytes(String assetId) {
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '/A8AAusB9Y9Z4WQAAAAASUVORK5CYII=',
    );
  }
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

  testWidgets('rich content renders inline question images', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentRepositoryProvider.overrideWithValue(
            _ImageContentRepository(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: RichContent('材料前文\ue000asset-1\ue001材料后文'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('材料前文'), findsOneWidget);
    expect(find.text('材料后文'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('查看题图'), findsOneWidget);
  });
}
