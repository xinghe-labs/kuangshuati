import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kuangshuati/main.dart';

const updateManifest =
    'https://content.example.com/update-manifest.json';

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(finder, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('downloads and verifies the published APK', (tester) async {
    final app = await buildKuangshuatiApp();
    await tester.pumpWidget(app);
    await pumpUntil(
      tester,
      find.text('发现新版本 1.0.1'),
      timeout: const Duration(seconds: 45),
    );
    expect(find.text('验证应用内自动更新'), findsOneWidget);
    expect(find.text('包含最新功能优化'), findsOneWidget);

    await tester.tap(find.text('下载更新'));
    await pumpUntil(
      tester,
      find.text('安装更新'),
      timeout: const Duration(minutes: 10),
    );
    expect(find.text('安装包校验通过'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
