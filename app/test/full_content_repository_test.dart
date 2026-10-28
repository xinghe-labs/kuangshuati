import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'opens an installed full content package and reads questions and images',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kuangshuati-content-',
      );
      FullContentRepository? repository;
      try {
        final assets = _findAssetsDirectory();
        final parts =
            Directory(
                  '${assets.path}${Platform.pathSeparator}content${Platform.pathSeparator}parts',
                )
                .listSync()
                .whereType<File>()
                .where((file) => file.path.contains('.sqlite.part'))
                .toList()
              ..sort((left, right) => left.path.compareTo(right.path));
        expect(parts, isNotEmpty);
        final database = File(
          '${directory.path}${Platform.pathSeparator}content.sqlite',
        );
        final output = await database.open(mode: FileMode.write);
        try {
          for (final part in parts) {
            await output.writeFrom(await part.readAsBytes());
          }
          await output.flush();
        } finally {
          await output.close();
        }
        await File(
          '${assets.path}${Platform.pathSeparator}content${Platform.pathSeparator}content-manifest.json',
        ).copy(
          '${directory.path}${Platform.pathSeparator}content-installed.json',
        );
        repository = await FullContentRepository.openInstalled(
          supportDirectory: directory,
        );
        final stats = await repository.stats();
        expect(stats.questionCount, 58890);
        expect(stats.paperCount, 515);
        expect(stats.imageCount, 39196);
        expect(stats.contentVersion, '2026-10-25');

        final papers = await repository.searchPapers(query: '国考', year: 2026);
        expect(papers, isNotEmpty);
        final questions = await repository.questionsForPaper(papers.first.id);
        expect(questions, isNotEmpty);

        final marker = RegExp(r'\ue000([^\ue001]+)\ue001');
        String? assetId;
        for (final question in questions) {
          final content = [
            question.material ?? '',
            question.stem,
            question.solution,
            ...question.options.values,
          ].join('\n');
          final match = marker.firstMatch(content);
          if (match != null) {
            assetId = match.group(1);
            break;
          }
        }
        expect(
          assetId,
          isNotNull,
          reason: 'sample paper should contain a graph',
        );
        final image = await repository.imageBytes(assetId!);
        expect(image, isNotNull);
        expect(image, isNotEmpty);
        // 行内/块级分流依赖同步高度查询：必须能拿到与图片真实高度一致的值。
        final heights = repository.imageHeightsSync([assetId]);
        expect(heights[assetId], isNotNull, reason: 'asset height must be indexed');
        expect(heights[assetId], greaterThan(0));
        expect(
          repository.imageHeightsSync(['asset_does_not_exist']),
          isEmpty,
          reason: 'unknown asset must not be reported as inline-sized',
        );
        final codec = await ui.instantiateImageCodec(image!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        expect(heights[assetId], frame.image.height);
        frame.image.dispose();
        codec.dispose();
      } finally {
        repository?.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Directory _findAssetsDirectory() {
  final candidates = [
    Directory('${Directory.current.path}${Platform.pathSeparator}assets'),
    Directory(
      '${Directory.current.path}${Platform.pathSeparator}app${Platform.pathSeparator}assets',
    ),
  ];
  return candidates.firstWhere(
    (directory) => directory.existsSync(),
    orElse: () => throw StateError(
      'Unable to locate app assets from ${Directory.current.path}',
    ),
  );
}
