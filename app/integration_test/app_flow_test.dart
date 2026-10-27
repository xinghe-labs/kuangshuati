import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes and resumes a mobile practice flow', (tester) async {
    await tester.pumpWidget(await buildKuangshuatiApp());
    await pumpUntil(tester, find.text('随机开始'));

    await tester.tap(find.text('随机开始'));
    await pumpUntil(tester, find.textContaining('第 1 /'));
    expect(find.text('提交答案'), findsOneWidget);

    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('提交答案'));
    await pumpUntil(tester, find.text('下一题'));
    expect(
      find.text('回答正确').evaluate().isNotEmpty ||
          find.text('回答错误').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.tap(find.byTooltip('返回'));
    await pumpUntil(tester, find.text('继续练习'));
    await tester.tap(find.text('继续练习'));

    await pumpUntil(tester, find.text('下一题'));
    expect(find.textContaining('第 1 /'), findsOneWidget);
    expect(find.textContaining('正确答案：'), findsOneWidget);

    await tester.tap(find.text('下一题'));
    await pumpUntil(tester, find.textContaining('第 2 /'));
    expect(find.text('提交答案'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await pumpUntil(tester, find.text('继续练习'));

    await tester.tap(find.text('题库').last);
    await pumpUntil(tester, find.text('按试卷练习，或从收藏中挑出需要反复看的题。'));

    await tester.tap(find.text('错题').last);
    await pumpUntil(tester, find.text('答错的题按阶段自动回来；也可以提前重做或标记已掌握。'));

    await tester.tap(find.text('统计').last);
    await pumpUntil(tester, find.text('只看能指导下一步练习的数据，不做无关的排名和积分。'));

    await tester.tap(find.text('设置').last);
    await pumpUntil(tester, find.text('偏好立即生效并保存在本机。'));
    expect(find.text('作答后立即显示答案'), findsOneWidget);
    expect(find.text('离线题库'), findsOneWidget);
    expect(find.text('58890 道题 · 515 份试卷 · 39196 张图片'), findsOneWidget);
  });
}
