import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/splash/splash_screen.dart';

void main() {
  testWidgets('先播启动动效，初始化完成后淡入 App', (tester) async {
    final completer = Completer<Widget>();
    await tester.pumpWidget(
      SplashGate(
        bootstrap: () => completer.future,
        minimumDuration: const Duration(milliseconds: 200),
      ),
    );

    // 初始化还没完成：停在动效上。
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('真正的 App'), findsNothing);

    completer.complete(
      const MaterialApp(home: Scaffold(body: Text('真正的 App'))),
    );
    await tester.pump();
    // 最短展示时长还没到，仍然在动效上。
    expect(find.text('真正的 App'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('真正的 App'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('初始化很快时也不会只闪一帧动效', (tester) async {
    await tester.pumpWidget(
      SplashGate(
        bootstrap: () async => const MaterialApp(
          home: Scaffold(body: Text('真正的 App')),
        ),
        minimumDuration: const Duration(milliseconds: 520),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('真正的 App'), findsOneWidget);
  });

  testWidgets('初始化失败时给重试入口，而不是停在启动图上', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      SplashGate(
        bootstrap: () async {
          attempts++;
          if (attempts == 1) throw StateError('题库打不开');
          return const MaterialApp(home: Scaffold(body: Text('真正的 App')));
        },
        minimumDuration: const Duration(milliseconds: 50),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('应用启动失败'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('真正的 App'), findsOneWidget);
    expect(attempts, 2);
  });
}
