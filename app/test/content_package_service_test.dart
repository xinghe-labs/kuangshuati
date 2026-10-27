import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/content/content_package_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test 会把 HttpOverrides.global 换成返回 400 的 mock，
  // 置空以恢复真实 HttpClient；本文件不需要 mock HTTP。
  HttpOverrides.global = null;

  test(
    'downloads four ranges and installs a verified content package',
    () async {
      final root = await Directory.systemTemp.createTemp('content-service-');
      final sourceDb = File('${root.path}/source.sqlite');
      final database = sqlite3.open(sourceDb.path);
      database.execute(
        'CREATE TABLE questions (id INTEGER PRIMARY KEY, stem TEXT)',
      );
      database.execute("INSERT INTO questions VALUES (1, '测试题')");
      database.close();
      final databaseBytes = await sourceDb.readAsBytes();
      final packageBytes = gzip.encode(databaseBytes);
      final packageFile = File('${root.path}/content.sqlite.gz');
      await packageFile.writeAsBytes(packageBytes, flush: true);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      final subscription = server.listen((request) async {
        requestCount += 1;
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range == null || !range.startsWith('bytes=')) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        final values = range.substring(6).split('-');
        final start = int.parse(values[0]);
        final end = int.parse(values[1]);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${packageBytes.length}',
        );
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.contentLength = end - start + 1;
        request.response.add(packageBytes.sublist(start, end + 1));
        await request.response.close();
      });

      try {
        final manifest = ContentPackageManifest(
          contentVersion: 'test-1',
          minimumAppVersionCode: 1,
          questionCount: 1,
          paperCount: 1,
          imageCount: 0,
          databaseBytes: databaseBytes.length,
          databaseSha256: _sha256(databaseBytes),
          packageUrl: Uri.parse(
            'http://${server.address.address}:${server.port}/content.sqlite.gz',
          ),
          packageBytes: packageBytes.length,
          packageSha256: _sha256(packageBytes),
        );
        final support = Directory('${root.path}/support');
        final temporary = Directory('${root.path}/temporary');
        final service = ContentPackageService(
          manifestUrl: 'https://example.com/content-manifest.json',
          proxy: '',
          supportDirectory: support,
          temporaryDirectory: temporary,
          segmentCount: 4,
        );
        final stages = <String>[];
        await service.install(
          manifest,
          onProgress: (progress, stage) {
            expect(progress, inInclusiveRange(0, 1));
            if (stages.isEmpty || stages.last != stage) stages.add(stage);
          },
        );

        expect(requestCount, 4);
        expect(stages, contains('正在下载题库'));
        expect(stages.last, '题库安装完成');
        final installed = File('${support.path}/content.sqlite');
        expect(await installed.readAsBytes(), databaseBytes);
        final installedManifest = await service.readInstalledManifest();
        expect(installedManifest?.contentVersion, 'test-1');
      } finally {
        await subscription.cancel();
        await server.close(force: true);
        await root.delete(recursive: true);
      }
    },
  );
}

String _sha256(List<int> bytes) {
  return sha256.convert(bytes).toString();
}
