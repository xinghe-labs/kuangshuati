import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/splash/splash_screen.dart';

void main() {
  testWidgets('先播完动效再初始化，然后淡入 App', (tester) async {
    var bootstrapCalls = 0;
    await tester.pumpWidget(
      SplashGate(
        bootstrap: () async {
          bootstrapCalls++;
          return const MaterialApp(home: Scaffold(body: Text('真正的 App')));
        },
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    // 动效还没播完，初始化不应该开始：它会占住 UI 线程把动画卡住。
    expect(bootstrapCalls, 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(bootstrapCalls, 0, reason: '动效播放期间不能开始初始化');

    await tester.pump(const Duration(milliseconds: 400));
    expect(bootstrapCalls, 1, reason: '动效播完才开始初始化');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('真正的 App'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('初始化慢时停在动效上，不会先闪一屏空白', (tester) async {
    final completer = Completer<Widget>();
    await tester.pumpWidget(SplashGate(bootstrap: () => completer.future));

    await tester.pump(const Duration(milliseconds: 700));
    // 动效播完但初始化没结束：仍然停在启动页。
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('真正的 App'), findsNothing);

    completer.complete(
      const MaterialApp(home: Scaffold(body: Text('真正的 App'))),
    );
    await tester.pump();
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
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('应用启动失败'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('真正的 App'), findsOneWidget);
    expect(attempts, 2);
  });
}
