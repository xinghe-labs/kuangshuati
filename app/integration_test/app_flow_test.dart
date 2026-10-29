import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/content/content_manager.dart';
import 'package:kuangshuati/main.dart';

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(finder, findsWidgets);
}

/// 真机流程测试用固定题库，避免依赖 145MB 线上包是否已下载：
/// 这些用例要验证的是交互链路，不是内容体量（内容由 `tools/verify_content_package.py`
/// 和 `test/full_content_repository_test.dart` 负责）。
Future<ContentRepository> _seedContent() async => SeedContentRepository();

Future<Widget> _buildApp(AppDatabase userDatabase) async {
  final content = await _seedContent();
  return buildKuangshuatiApp(
    userDatabase: userDatabase,
    contentManager: ContentManager.forTesting(content),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 每个用例各自建一个内存库，drift 的“同进程多实例”警告在此属预期。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('completes and resumes a mobile practice flow', (tester) async {
    const updateChannel = MethodChannel('com.kuangshuati.app/updates');
    final nativeVersion = await updateChannel.invokeMapMethod<String, Object?>(
      'getVersion',
    );
    // 不写死具体版本号，否则每次发版都要改测试；这里只验证原生通道能读到版本。
    // debug 包带 `-debug` 后缀，所以只校验版本号主干。
    expect(
      nativeVersion?['versionName'],
      matches(RegExp(r'^\d+\.\d+\.\d+(-[\w.]+)?$')),
    );
    expect(nativeVersion?['versionCode'], greaterThan(0));
    expect(
      await updateChannel.invokeMethod<bool>('canInstallPackages'),
      isA<bool>(),
    );

    final userDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(await _buildApp(userDatabase));
    await pumpUntil(tester, find.text('随机开始'));

    await tester.tap(find.text('随机开始'));
    await pumpUntil(tester, find.textContaining('第 1 /'));
    expect(find.text('提交答案'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('标记不确定'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('标记不确定'));
    await tester.pump();
    expect(find.text('已标记不确定'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.bookmark_outline),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.bookmark_outline));
    await pumpUntil(tester, find.text('已加入收藏'));
    expect(await userDatabase.allFavorites(), hasLength(1));
    await tester.tap(find.byTooltip('答题卡'));
    await pumpUntil(tester, find.text('答题卡'));
    expect(find.textContaining('已答 0 / '), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.scrollUntilVisible(
      find.text('A').first,
      -260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('提交答案'));
    await pumpUntil(tester, find.text('下一题'));
    await tester.scrollUntilVisible(
      find.textContaining('正确答案：'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('正确答案：'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await pumpUntil(tester, find.text('继续练习'));
    await tester.tap(find.text('继续练习'));

    await pumpUntil(tester, find.text('下一题'));
    expect(find.textContaining('第 1 /'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('正确答案：'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('正确答案：'), findsOneWidget);

    await tester.tap(find.text('下一题'));
    await pumpUntil(tester, find.textContaining('第 2 /'));
    expect(find.text('提交答案'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await pumpUntil(tester, find.text('继续练习'));

    await tester.tap(find.text('题库').last);
    await pumpUntil(tester, find.text('按试卷练习，或从收藏中挑出需要反复看的题。'));
    await tester.enterText(find.byType(TextField), '2026');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('2026'), findsWidgets);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('收藏'));
    await pumpUntil(tester, find.text('练习全部 1 题'));

    await tester.tap(find.text('错题').last);
    await pumpUntil(tester, find.text('答错的题按阶段自动回来；也可以提前重做或标记已掌握。'));

    await tester.tap(find.text('统计').last);
    await pumpUntil(tester, find.text('只看能指导下一步练习的数据，不做无关的排名和积分。'));

    await tester.tap(find.text('设置').last);
    await pumpUntil(tester, find.text('偏好立即生效并保存在本机。'));
    expect(find.text('作答后立即显示答案'), findsOneWidget);
    expect(find.text('离线题库'), findsOneWidget);
    expect(find.text('备份与恢复'), findsOneWidget);
    // 设置页只显示题库版本号；题量统计由安装页和校验脚本负责。
    expect(find.text('版本 demo'), findsOneWidget);

    // “检查更新”在「关于」分组，默认在首屏外（ListView 懒构建），
    // 必须先滚动到可见，否则 finder 找不到它并不代表功能缺失。
    await tester.scrollUntilVisible(
      find.text('检查更新'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('检查更新'), findsOneWidget);
    await tester.tap(find.text('检查更新'));
    await pumpUntil(tester, find.text('当前安装包尚未配置应用更新源'));
  });

  testWidgets('mock exam hides answers until submit and finishes once', (
    tester,
  ) async {
    final userDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final app = await _buildApp(userDatabase);
    await tester.pumpWidget(app);
    await pumpUntil(tester, find.text('随机开始'));

    // 题库 → 第一套试卷的“整卷模考”。
    await tester.tap(find.text('题库').last);
    await pumpUntil(tester, find.text('按试卷练习，或从收藏中挑出需要反复看的题。'));
    await tester.tap(find.byIcon(Icons.more_horiz).first);
    // 不能 pumpAndSettle：题库页存在不确定时长的 CircularProgressIndicator，
    // 会让 pumpAndSettle 一直等到 10 分钟默认超时。
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('整卷模考'));
    await pumpUntil(tester, find.textContaining('第 1 /'));

    // 开发文档 §9.3：模考只保存选择，不判题、不显示解析。
    expect(find.text('提交答案'), findsNothing);
    // 模考页选项在下方，要正向（向下）滚动才能看到；delta 用正值，
    // 且不用 scrollUntilVisible（其末尾的 ensureVisible 可能永不完成）。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('正确答案：'), findsNothing);
    expect(find.text('下一题'), findsOneWidget);
    await tester.tap(find.text('下一题'));
    await pumpUntil(tester, find.textContaining('第 2 /'));
    expect(find.textContaining('正确答案：'), findsNothing);

    await tester.tap(find.text('交卷'));
    await pumpUntil(tester, find.text('确认交卷'));
    // 对话框标题和确认按钮都叫“确认交卷”，必须明确点按钮本身。
    await tester.tap(find.widgetWithText(FilledButton, '确认交卷'));
    await pumpUntil(tester, find.text('% 得分率'));

    final daily = await userDatabase.watchDailyStats().first.timeout(
      const Duration(seconds: 10),
    );
    expect(daily.single.sessionsCount, 1);
    expect(daily.single.answeredCount, 1);
    // 模考得分率的分母是整卷题数，未答按零分，所以答对数不可能超过已答数。
    expect(daily.single.correctCount, lessThanOrEqualTo(1));
    expect(
      await userDatabase.latestActiveSession().timeout(
        const Duration(seconds: 10),
      ),
      isNull,
    );
    // 真机集成环境下 NativeDatabase.memory().close() 会挂起（sqlite3 异步
    // 关闭回调不返回），而用例结束进程即回收内存库，无需显式关闭。
  });

  testWidgets('auto submits an expired mock exam through the same path', (
    tester,
  ) async {
    final userDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.pumpWidget(await _buildApp(userDatabase));
    await pumpUntil(tester, find.text('随机开始'));

    // 直接造一场“已经超时”的模考，省去手动等倒计时。
    final content = await _seedContent();
    final questions = await content.randomQuestions(3);
    expect(questions, hasLength(3));
    await userDatabase.createSession(
      id: 'auto-timeout',
      mode: PracticeMode.mock,
      title: '超时模考',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
      requestedCount: 3,
      timeLimitSeconds: 1,
    );
    await tester.pump(const Duration(seconds: 2));

    // 首页应优先提供“继续练习”；进去后计时器发现已过 deadline，
    // 走与主动交卷同一个入口自动交卷。
    await pumpUntil(tester, find.text('继续练习'));
    await tester.tap(find.text('继续练习'));
    await pumpUntil(tester, find.text('% 得分率'));
    expect(find.textContaining('考试时间已到'), findsWidgets);

    final daily = await userDatabase.watchDailyStats().first.timeout(
      const Duration(seconds: 10),
    );
    expect(daily.single.sessionsCount, 1);
    expect(
      await userDatabase.latestActiveSession().timeout(
        const Duration(seconds: 10),
      ),
      isNull,
    );

    // 自动交卷只执行一次：回到首页再继续，不能再多出一场统计。
    await tester.tap(find.text('返回首页'));
    await pumpUntil(tester, find.text('随机开始'));
    expect(
      (await userDatabase.watchDailyStats().first).single.sessionsCount,
      1,
    );
    // 真机集成环境下 NativeDatabase.memory().close() 会挂起（sqlite3 异步
    // 关闭回调不返回），而用例结束进程即回收内存库，无需显式关闭。
  });
}
