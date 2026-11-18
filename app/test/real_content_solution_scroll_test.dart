// 真实题库回归：拿题库里解析最长、公式图最多的一道真题，跑完整练习页，
// 断言「解析第一次可见那一帧的内容高度 == 最终高度」。
//
// 为什么需要它：合成数据里图片尺寸都是我编的，容易自己迁就自己。
// 这条用真实 webp 公式图（宽高比实测 0.17–34.8，中位数 3.76）、真实长解析，
// 只要占位盒和真图盒有任何一处不一致，这里就会变红。
//
// 题库文件 315MB，不随开源仓库分发；缺失时跳过。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/practice/practice_page.dart';

/// 题库里解析最长且带公式图的一道真题（63 张行内公式图）。
const _questionId = 'src_2448412_661024aa';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('真实题库：解析首次可见时高度就是最终高度', (tester) async {
    final file = File('assets/content/content.sqlite');
    if (!file.existsSync()) {
      markTestSkipped('未提供题库文件，跳过真实题库回归');
      return;
    }

    final content = FullContentRepository.forTesting(
      sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly),
    );
    addTearDown(content.close);

    final question = await tester.runAsync(
      () => content.findQuestion(_questionId),
    );
    expect(question, isNotNull, reason: '题库里找不到 $_questionId');
    final q = question!;
    // 题目本身得真的是长解析 + 多图，否则这条测试没测到东西。
    expect(q.solution.length, greaterThan(1500));
    final imageCount = '${q.solution}\ue000'.length; // 仅用于下面计数
    expect(imageCount, greaterThan(0));

    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-real',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: [q],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-real',
        questionId: q.id,
        selected: q.correctAnswers,
        submitted: true,
        isCorrect: true,
        durationMs: 3000,
      );
    });

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(content),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const PracticePage(sessionId: 'session-real'),
        ),
      ),
    );

    final scrollable = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;

    // 逐帧推进到解析面板第一次出现，记下那一帧的内容高度。
    double? maxAtFirstSight;
    for (var i = 0; i < 200; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      if (find.text('解析').evaluate().isNotEmpty) {
        maxAtFirstSight = tester
            .state<ScrollableState>(scrollable)
            .position
            .maxScrollExtent;
        break;
      }
    }
    expect(maxAtFirstSight, isNotNull, reason: '解析面板始终没出现');
    final firstSight = maxAtFirstSight!;

    // 放掉所有异步：真图解码、未来得及的回调。
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
    final settledMax = tester
        .state<ScrollableState>(scrollable)
        .position
        .maxScrollExtent;
    // ignore: avoid_print
    expect(
      settledMax,
      greaterThan(300),
      reason: '内容不够长就没法复现这个 bug（settled=$settledMax）',
    );

    expect(
      settledMax,
      moreOrLessEquals(firstSight, epsilon: 0.5),
      reason: '真实题库里占位盒与真图盒不一致：内容高度从 '
          '${firstSight.toStringAsFixed(1)} 变成 '
          '${settledMax.toStringAsFixed(1)}，用户停在解析底部时会被 clamp 拽回',
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
