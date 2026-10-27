import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/updates/update_service.dart';

void main() {
  final manifest = <String, Object>{
    'schemaVersion': 1,
    'platform': 'android',
    'versionCode': 2,
    'versionName': '1.0.1',
    'apkUrl': 'https://example.com/kuangshuati-1.0.1.apk',
    'apkSha256': 'a' * 64,
    'apkSize': 123456,
    'releaseNotes': ['修复练习恢复', '优化题图加载'],
    'mandatory': false,
  };

  test('parses a newer Android update', () {
    final update = UpdateService.parseManifest(
      jsonEncode(manifest),
      currentVersionCode: 1,
    );
    expect(update, isNotNull);
    expect(update!.versionName, '1.0.1');
    expect(update.versionCode, 2);
    expect(update.apkSize, 123456);
    expect(update.releaseNotes, ['修复练习恢复', '优化题图加载']);
  });

  test('ignores the current or an older version', () {
    expect(
      UpdateService.parseManifest(jsonEncode(manifest), currentVersionCode: 2),
      isNull,
    );
    expect(
      UpdateService.parseManifest(jsonEncode(manifest), currentVersionCode: 3),
      isNull,
    );
  });

  test('rejects an insecure APK URL', () {
    final invalid = Map<String, Object>.from(manifest)
      ..['apkUrl'] = 'http://example.com/update.apk';
    expect(
      () => UpdateService.parseManifest(
        jsonEncode(invalid),
        currentVersionCode: 1,
      ),
      throwsA(isA<UpdateException>()),
    );
  });

  test('rejects an invalid digest', () {
    final invalid = Map<String, Object>.from(manifest)
      ..['apkSha256'] = 'not-a-digest';
    expect(
      () => UpdateService.parseManifest(
        jsonEncode(invalid),
        currentVersionCode: 1,
      ),
      throwsA(isA<UpdateException>()),
    );
  });

  test('rejects an unsupported manifest schema', () {
    final invalid = Map<String, Object>.from(manifest)
      ..['schemaVersion'] = 2;
    expect(
      () => UpdateService.parseManifest(
        jsonEncode(invalid),
        currentVersionCode: 1,
      ),
      throwsA(isA<UpdateException>()),
    );
  });

  test('downloads and verifies an APK payload', () async {
    final payload = List<int>.generate(4096, (index) => index % 251);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..add(payload)
        ..close();
    });
    final directory = await Directory.systemTemp.createTemp(
      'kuangshuati-update-test-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final update = UpdateInfo(
      versionName: '1.0.1',
      versionCode: 2,
      apkUrl: Uri.parse(
        'http://${server.address.address}:${server.port}/update.apk',
      ),
      apkSha256: sha256.convert(payload).toString(),
      apkSize: payload.length,
      releaseNotes: const [],
      mandatory: false,
    );
    final progress = <double>[];

    final service = UpdateService(
      manifestUrl: '',
      temporaryDirectory: () async => directory,
    );
    final file = await service.downloadApk(
      update,
      onProgress: (received, total) => progress.add(received / total),
    );

    expect(await file.readAsBytes(), payload);
    expect(progress.last, 1);
  });

  test('deletes a payload with a mismatched digest', () async {
    final payload = utf8.encode('not the expected APK');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..add(payload)
        ..close();
    });
    final directory = await Directory.systemTemp.createTemp(
      'kuangshuati-update-test-',
    );
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final update = UpdateInfo(
      versionName: '1.0.1',
      versionCode: 2,
      apkUrl: Uri.parse(
        'http://${server.address.address}:${server.port}/update.apk',
      ),
      apkSha256: 'a' * 64,
      apkSize: payload.length,
      releaseNotes: const [],
      mandatory: false,
    );

    final service = UpdateService(
      manifestUrl: '',
      temporaryDirectory: () async => directory,
    );

    await expectLater(
      service.downloadApk(update, onProgress: (received, total) {}),
      throwsA(isA<UpdateException>()),
    );
    expect(
      await File('${directory.path}/kuangshuati-update.apk').exists(),
      isFalse,
    );
  });
}
