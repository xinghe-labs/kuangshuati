// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/shared/widgets/app_widgets.dart';

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
}
