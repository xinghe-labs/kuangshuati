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

  group('segmentCountForBytes', () {
    // 347MB 的真实题库包：8MB 一片 → 44 片，被上限夹到 maxAutoSegments。
    test('caps the real 347MB package at maxAutoSegments', () {
      const packageBytes = 347 * 1024 * 1024;
      expect(
        ContentPackageService.segmentCountForBytes(packageBytes),
        ContentPackageService.maxAutoSegments,
      );
      // 每片不应小于最小片大小，否则请求数白涨。
      final segments = ContentPackageService.segmentCountForBytes(packageBytes);
      expect(packageBytes / segments, greaterThanOrEqualTo(8 * 1024 * 1024));
    });

    test('uses a single segment for anything up to the chunk size', () {
      expect(ContentPackageService.segmentCountForBytes(0), 1);
      expect(ContentPackageService.segmentCountForBytes(1024), 1);
      expect(
        ContentPackageService.segmentCountForBytes(
          ContentPackageService.minimumChunkBytes,
        ),
        1,
      );
    });

    test('scales with size between the two ends', () {
      expect(
        ContentPackageService.segmentCountForBytes(
          ContentPackageService.minimumChunkBytes * 3 +
              ContentPackageService.minimumChunkBytes ~/ 2,
        ),
        4,
      );
    });
  });

  test(
    'downloads multiple ranges and installs a verified content package',
    () async {
      final package = await _buildPackage();
      final server = await _serveBytes(package.compressed);
      final root = await Directory.systemTemp.createTemp('content-service-');
      try {
        final service = _serviceFor(root);
        final stages = <String>[];
        await service.install(
          package.manifest(packageUrl: server.url),
          onProgress: (progress, stage) {
            expect(progress, inInclusiveRange(0, 1));
            if (stages.isEmpty || stages.last != stage) stages.add(stage);
          },
        );

        expect(server.requests(), 4);
        expect(stages, contains('正在下载题库'));
        expect(stages.last, '题库安装完成');
        final installed = File('${_support(root).path}/content.sqlite');
        expect(await installed.readAsBytes(), package.database);
        final installedManifest = await service.readInstalledManifest();
        expect(installedManifest?.contentVersion, 'test-1');
      } finally {
        await server.close();
        await root.delete(recursive: true);
      }
    },
  );

  test('a small package is not split into many tiny requests', () async {
    // 不指定分片数时按包大小自动决定：测试包远小于 8MB，
    // 只应发一个 Range 请求，而不是默认劈成很多片。
    final package = await _buildPackage();
    final server = await _serveBytes(package.compressed);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root, segmentCount: null);
      await service.install(
        package.manifest(packageUrl: server.url),
        onProgress: (_, _) {},
      );
      expect(server.requests(), 1);
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  test('more segments than connections still installs every byte', () async {
    // 分片数故意超过 maxConcurrentSegments：先下完的连接要接下一片，
    // 不能漏片，也不能把同一片重复写两次。
    final extra = 6;
    final segments = ContentPackageService.maxConcurrentSegments + extra;
    final package = await _buildPackage();
    final server = await _serveBytes(package.compressed);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root, segmentCount: segments);
      final progress = <double>[];
      await service.install(
        package.manifest(packageUrl: server.url),
        onProgress: (value, _) => progress.add(value),
      );

      expect(server.requests(), segments);
      final installed = File('${_support(root).path}/content.sqlite');
      expect(await installed.readAsBytes(), package.database);
      // 进度必须单调不减，否则界面上会“倒着走”。
      for (var index = 1; index < progress.length; index++) {
        expect(progress[index], greaterThanOrEqualTo(progress[index - 1]));
      }
      expect(progress.last, 1.0);
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  test('rejects a package whose digest does not match the manifest', () async {
    final package = await _buildPackage();
    final server = await _serveBytes(package.compressed);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root);
      await expectLater(
        service.install(
          package.manifest(
            packageUrl: server.url,
            // 清单写的摘要和实际下发的字节不一致。
            packageSha256: _sha256(const [1, 2, 3]),
          ),
          onProgress: (_, _) {},
        ),
        throwsA(
          isA<ContentPackageException>().having(
            (error) => error.message,
            'message',
            contains('校验失败'),
          ),
        ),
      );
      expect(
        await File('${_support(root).path}/content.sqlite').exists(),
        isFalse,
      );
      expect(await service.readInstalledManifest(), isNull);
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  test('rejects a package that is not gzip at all', () async {
    final package = await _buildPackage();
    final garbage = List<int>.filled(package.compressed.length, 0x7f);
    final server = await _serveBytes(garbage);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root);
      await expectLater(
        service.install(
          package.manifest(packageUrl: server.url),
          onProgress: (_, _) {},
        ),
        throwsA(isA<ContentPackageException>()),
      );
      expect(
        await File('${_support(root).path}/content.sqlite').exists(),
        isFalse,
      );
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  test('rejects a gzip payload that hides a corrupt database', () async {
    final package = await _buildPackage();
    // 一段长度正确、摘要自洽的垃圾数据：解压成功、摘要匹配，
    // 但 sqlite quick_check 必须把它拦下来。
    final garbageDb = List<int>.generate(
      package.database.length,
      (i) => i % 251,
    );
    final compressed = gzip.encode(garbageDb);
    final server = await _serveBytes(compressed);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root);
      await expectLater(
        service.install(
          package.manifest(
            packageUrl: server.url,
            database: garbageDb,
            compressed: compressed,
          ),
          onProgress: (_, _) {},
        ),
        throwsA(isA<ContentPackageException>()),
      );
      expect(
        await File('${_support(root).path}/content.sqlite').exists(),
        isFalse,
      );
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });

  test('a failed update keeps the previously installed package', () async {
    final good = await _buildPackage(version: 'test-1');
    final server = await _serveBytes(good.compressed);
    final root = await Directory.systemTemp.createTemp('content-service-');
    try {
      final service = _serviceFor(root);
      await service.install(
        good.manifest(packageUrl: server.url),
        onProgress: (_, _) {},
      );
      final installedFile = File('${_support(root).path}/content.sqlite');
      final goodBytes = await installedFile.readAsBytes();

      // 第二次安装换成坏包：安装失败不得破坏已经在用的题库。
      final broken = await _buildPackage(version: 'test-2');
      final tampered = List<int>.from(broken.compressed);
      tampered[tampered.length ~/ 2] = tampered[tampered.length ~/ 2] ^ 0xff;
      final brokenServer = await _serveBytes(tampered);
      try {
        await expectLater(
          service.install(
            broken.manifest(packageUrl: brokenServer.url),
            onProgress: (_, _) {},
          ),
          throwsA(isA<ContentPackageException>()),
        );
      } finally {
        await brokenServer.close();
      }

      expect(await installedFile.readAsBytes(), goodBytes);
      final manifest = await service.readInstalledManifest();
      expect(manifest?.contentVersion, 'test-1');
    } finally {
      await server.close();
      await root.delete(recursive: true);
    }
  });
}

Directory _support(Directory root) => Directory('${root.path}/support');

ContentPackageService _serviceFor(Directory root, {int? segmentCount = 4}) =>
    ContentPackageService(
      manifestUrl: 'https://example.com/content-manifest.json',
      proxy: '',
      supportDirectory: _support(root),
      temporaryDirectory: Directory('${root.path}/temporary'),
      segmentCount: segmentCount,
    );

class _TestPackage {
  _TestPackage({
    required this.database,
    required this.compressed,
    required this.version,
  });

  final List<int> database;
  final List<int> compressed;
  final String version;

  ContentPackageManifest manifest({
    required Uri packageUrl,
    List<int>? database,
    List<int>? compressed,
    String? packageSha256,
  }) {
    final databaseBytes = database ?? this.database;
    final packageBytes = compressed ?? this.compressed;
    return ContentPackageManifest(
      contentVersion: version,
      minimumAppVersionCode: 1,
      questionCount: 1,
      paperCount: 1,
      imageCount: 0,
      databaseBytes: databaseBytes.length,
      databaseSha256: _sha256(databaseBytes),
      packageUrl: packageUrl,
      packageBytes: packageBytes.length,
      packageSha256: packageSha256 ?? _sha256(packageBytes),
    );
  }
}

Future<_TestPackage> _buildPackage({String version = 'test-1'}) async {
  final root = await Directory.systemTemp.createTemp('content-source-');
  try {
    final sourceDb = File('${root.path}/source.sqlite');
    final database = sqlite3.open(sourceDb.path);
    database.execute(
      'CREATE TABLE questions (id INTEGER PRIMARY KEY, stem TEXT)',
    );
    database.execute("INSERT INTO questions VALUES (1, '测试题')");
    database.close();
    final bytes = await sourceDb.readAsBytes();
    return _TestPackage(
      database: bytes,
      compressed: gzip.encode(bytes),
      version: version,
    );
  } finally {
    await root.delete(recursive: true);
  }
}

Future<_TestServer> _serveBytes(List<int> bytes) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var requests = 0;
  final subscription = server.listen((request) async {
    requests += 1;
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
      'bytes $start-$end/${bytes.length}',
    );
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.contentLength = end - start + 1;
    request.response.add(bytes.sublist(start, end + 1));
    await request.response.close();
  });
  return _TestServer(
    url: Uri.parse(
      'http://${server.address.address}:${server.port}/content.sqlite.gz',
    ),
    requests: () => requests,
    close: () async {
      await subscription.cancel();
      await server.close(force: true);
    },
  );
}

class _TestServer {
  _TestServer({required this.url, required this.requests, required this.close});

  final Uri url;
  final int Function() requests;
  final Future<void> Function() close;
}

String _sha256(List<int> bytes) {
  return sha256.convert(bytes).toString();
}
