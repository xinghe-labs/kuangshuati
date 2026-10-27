import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'assembles the bundled content parts and reads questions and images',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kuangshuati-content-',
      );
      FullContentRepository? repository;
      try {
        repository = await FullContentRepository.open(
          bundle: rootBundle,
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
        final codec = await ui.instantiateImageCodec(image!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
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
