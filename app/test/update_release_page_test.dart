import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/updates/update_service.dart';

// 通道测试需要 TestWidgetsFlutterBinding，而它会让同文件里的 HttpClient
// 请求一律返回 400；update_service_test.dart 有真实本地 HTTP 下载测试，
// 所以这类测试单独放一个文件（每个测试文件是独立 isolate）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('openReleasePage（iOS 跳转下载页）', () {
    const channel = MethodChannel('com.kuangshuati.app/updates');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('通过原生通道打开 https 下载页', () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return true;
      });

      final opened = await UpdateService().openReleasePage();

      expect(opened, isTrue);
      expect(received?.method, 'openUrl');
      final url = (received?.arguments as Map)['url'] as String;
      expect(url, iosReleasePageUrl);
      expect(Uri.parse(url).scheme, 'https');
    });

    test('原生端未实现或返回空时不报错，返回 false', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw MissingPluginException(),
      );
      expect(await UpdateService().openReleasePage(), isFalse);

      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await UpdateService().openReleasePage(), isFalse);
    });
  });
}
