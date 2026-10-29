import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:kuangshuati/domain/models.dart';

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
        // 行内/块级分流依赖高度查询：必须能拿到与图片真实高度一致的值。
        final heights = await repository.imageHeights([assetId]);
        expect(
          heights[assetId],
          isNotNull,
          reason: 'asset height must be indexed',
        );
        expect(heights[assetId], greaterThan(0));
        expect(
          await repository.imageHeights(['asset_does_not_exist']),
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

        // 开发文档 §9.1：随机抽题以材料组为最小单位，整组取、不重复、至少凑满请求数。
        // 真实数据的两个例外已在仓储层处理：上游 group_id 为空的 43 904 道题，
        // 以及 35/50/60 题的超大材料组——它们按单题抽，否则会一次抽出整库或整节。
        final paperCache = <String, List<QuestionContent>>{};
        Future<Set<String>> groupOf(
          List<QuestionContent> sample,
          String groupId,
        ) async {
          final one = sample.firstWhere((item) => item.groupId == groupId);
          final paper = paperCache[one.paperId] ??= await repository!
              .questionsForPaper(one.paperId);
          return paper
              .where((item) => item.groupId == groupId)
              .map((item) => item.id)
              .toSet();
        }

        /// 整组抽到的材料组必须完整；装不下的超大组与空 group_id 允许单题抽。
        Future<void> expectGroupsIntact(
          List<QuestionContent> sample,
          int count,
        ) async {
          for (final groupId in sample.map((item) => item.groupId).toSet()) {
            if (groupId.isEmpty) continue;
            final expected = await groupOf(sample, groupId);
            if (expected.length > count) continue;
            final actual = sample
                .where((item) => item.groupId == groupId)
                .map((item) => item.id)
                .toSet();
            expect(
              actual,
              expected,
              reason: 'material group $groupId was split apart',
            );
          }
        }

        final random = await repository.randomQuestions(20);
        // 产品规则：随机练习固定 20 题。整组抽题不能把总题量撑过 count
        // （曾因最后一组超出被抽成 24 题）。
        expect(random.length, 20);
        expect(
          random.map((question) => question.id).toSet().length,
          random.length,
          reason: 'random sampling must not repeat a question',
        );
        await expectGroupsIntact(random, 20);

        // 资料分析题基本都是“一段材料 + 5 道小题”，专门验一遍整组语义。
        final materialSample = await repository.randomQuestions(
          10,
          module: '资料分析',
        );
        expect(materialSample.length, greaterThanOrEqualTo(10));
        expect(materialSample.map((question) => question.module).toSet(), {
          '资料分析',
        });
        final sampledGroups = materialSample
            .map((question) => question.groupId)
            .where((groupId) => groupId.isNotEmpty)
            .toSet();
        expect(
          sampledGroups,
          isNotEmpty,
          reason: '资料分析 questions must come with their material group',
        );
        expect(
          sampledGroups.any(
            (groupId) =>
                materialSample.where((item) => item.groupId == groupId).length >
                1,
          ),
          isTrue,
          reason: 'a 资料分析 group holds several sub-questions',
        );
        await expectGroupsIntact(materialSample, 10);
        final moduleSample = await repository.randomQuestions(
          6,
          module: '言语理解',
        );
        expect(
          moduleSample.every((question) => question.module == '言语理解'),
          isTrue,
        );
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
