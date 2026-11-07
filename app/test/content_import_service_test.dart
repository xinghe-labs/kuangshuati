import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/content/content_import_service.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';

/// 1x1 透明 PNG（官方测试同款字节）。
const _png1x1Base64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Map<String, Object> _validBank() => {
  'format': 'kuangshuati-bank',
  'formatVersion': 1,
  'name': '测试题库',
  'contentVersion': 'custom-test-1',
  'images': {
    'img1': {'mime': 'image/png', 'data': _png1x1Base64},
    'img2': {'mime': 'image/png', 'data': _png1x1Base64}, // 与 img1 同字节
    'img3': {'mime': 'image/png', 'data': _png1x1Base64}, // 同字节第三张
  },
  'papers': [
    {
      'id': 'P1',
      'title': '2024 国考行测',
      'year': 2024,
      'region': '国家',
      'paperType': '行测',
      'durationSeconds': 7200,
      'questions': [
        {
          'id': 'Q1',
          'module': '言语理解与表达',
          'type': '单选',
          'stem': '下面哪个是图片？[[img:img1]]',
          'options': {'A': '图一 [[img:img2]]', 'B': '图二 [[img:img3]]'},
          'answer': ['A'],
          'solution': '见图片',
        },
        {
          'id': 'Q2',
          'stem': '第二题',
          'options': {'A': '甲', 'B': '乙', 'C': '丙', 'D': '丁'},
          'answer': ['B', 'C'],
        },
      ],
    },
  ],
};

void main() {
  group('parseBankJson', () {
    test('合法题库解析出完整结构与默认值', () {
      final bank = parseBankJson(jsonEncode(_validBank()));
      expect(bank.name, '测试题库');
      expect(bank.contentVersion, 'custom-test-1');
      expect(bank.papers, hasLength(1));
      expect(bank.images, hasLength(3)); // 三个资产 ID（同字节，入库时会去重）

      final paper = bank.papers.single;
      expect(paper.id, 'P1');
      expect(paper.title, '2024 国考行测');
      expect(paper.year, 2024);
      expect(paper.questions, hasLength(2));

      final q1 = paper.questions[0];
      // questionNo 缺省 = 文档序号
      expect(q1.questionNo, 1);
      expect(q1.groupId, '');
      // [[img:ID]] 转成官方渲染标记
      expect(q1.stem, contains('\ue000img1\ue001'));
      expect(q1.stem, isNot(contains('[[img')));
      expect(q1.options['B'], contains('\ue000img3\ue001'));
      // stemText 从题干派生，图片标记被剔除
      expect(q1.stemText, '下面哪个是图片？');
      expect(q1.answers, ['A']);
    });

    test('用户提供的 stemText 优先于自动派生', () {
      final bank = _validBank();
      (bank['papers'] as List).first['questions'][0]['stemText'] = '自定义检索文本';
      final parsed = parseBankJson(jsonEncode(bank));
      expect(parsed.papers.single.questions[0].stemText, '自定义检索文本');
    });

    test('非 JSON / 根不是对象 / format 不对', () {
      expect(
        () => parseBankJson('{broken'),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('不是有效的 JSON'),
          ),
        ),
      );
      expect(
        () => parseBankJson('[1,2]'),
        throwsA(isA<ContentImportException>()),
      );
      expect(
        () => parseBankJson('{"format": "other"}'),
        throwsA(isA<ContentImportException>()),
      );
      expect(
        () => parseBankJson(
          '{"format": "kuangshuati-bank", "formatVersion": 99}',
        ),
        throwsA(isA<ContentImportException>()),
      );
    });

    test('错误信息带定位：重复题目 ID', () {
      final bank = _validBank();
      (bank['papers'] as List).first['questions'][1]['id'] = 'Q1';
      expect(
        () => parseBankJson(jsonEncode(bank)),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('papers[0].questions[1].id'),
          ),
        ),
      );
    });

    test('错误信息带定位：answer 不在 options 里', () {
      final bank = _validBank();
      (bank['papers'] as List).first['questions'][1]['answer'] = ['E'];
      expect(
        () => parseBankJson(jsonEncode(bank)),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('papers[0].questions[1].answer'),
          ),
        ),
      );
    });

    test('引用未定义的图片报错', () {
      final bank = _validBank();
      (bank['images'] as Map).remove('img1');
      expect(
        () => parseBankJson(jsonEncode(bank)),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('未定义的图片 "img1"'),
          ),
        ),
      );
    });

    test('data URI 自动取 mime', () {
      final bank = _validBank();
      (bank['images'] as Map)['img1'] = {
        'data': 'data:image/webp;base64,$_png1x1Base64',
      };
      final parsed = parseBankJson(jsonEncode(bank));
      expect(parsed.images['img1']!.mime, 'image/webp');
    });
  });

  group('ContentImportService.importFromFile', () {
    late Directory root;
    late Directory support;
    late Directory temporary;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('ks-import-test');
      support = Directory('${root.path}/support');
      temporary = Directory('${root.path}/temporary');
      await support.create();
      await temporary.create();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<File> writeBank(Object bank, String name) async {
      final file = File('${root.path}/$name');
      await file.writeAsString(jsonEncode(bank));
      return file;
    }

    test('端到端：导入 → 原子落盘 → openInstalled 可读', () async {
      final file = await writeBank(_validBank(), 'bank.json');
      final service = ContentImportService(
        supportDirectory: support,
        temporaryDirectory: temporary,
      );

      final stages = <String>[];
      final summary = await service.importFromFile(
        file.path,
        onProgress: (_, stage) => stages.add(stage),
      );

      expect(summary.name, '测试题库');
      expect(summary.contentVersion, 'custom-test-1');
      expect(summary.questionCount, 2);
      expect(summary.paperCount, 1);
      // img1/img2 字节相同，images 表只存一份
      expect(summary.imageCount, 1);
      expect(stages, contains('正在解析题库'));
      expect(stages.last, '题库导入完成');

      // 落盘产物
      expect(await File('${support.path}/content.sqlite').exists(), isTrue);
      expect(
        await File('${support.path}/content-installed.json').exists(),
        isTrue,
      );
      // 工作目录已清理
      expect(
        await Directory('${temporary.path}/content-import').exists(),
        isFalse,
      );

      final repository = await FullContentRepository.openInstalled(
        supportDirectory: support,
      );
      final stats = await repository.stats();
      expect(stats.questionCount, 2);
      expect(stats.paperCount, 1);
      final question = await repository.findQuestion('Q1');
      expect(question, isNotNull);
      expect(question!.stem, contains('\ue000img1\ue001'));
      await repository.close();
    });

    test('导入失败时旧题库完好（原子性）', () async {
      final goodFile = await writeBank(_validBank(), 'good.json');
      final service = ContentImportService(
        supportDirectory: support,
        temporaryDirectory: temporary,
      );
      await service.importFromFile(goodFile.path);

      final badBank = _validBank();
      (badBank['papers'] as List).first['questions'][0]['answer'] = ['Z'];
      final badFile = await writeBank(badBank, 'bad.json');

      await expectLater(
        service.importFromFile(badFile.path),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('papers[0].questions[0].answer'),
          ),
        ),
      );

      final repository = await FullContentRepository.openInstalled(
        supportDirectory: support,
      );
      final stats = await repository.stats();
      expect(stats.questionCount, 2);
      expect(stats.contentVersion, 'custom-test-1');
      await repository.close();
    });

    test('文件超过 64MB 拒绝导入', () async {
      final file = await writeBank(_validBank(), 'bank.json');
      // 直接构造一个超限文件（稀疏写法：合法 JSON 之外补足字节数不行，
      // 所以改为在 contentVersion 里塞超长字符串；这里用更直接的方式：
      // 写一个超大的空白文件即可触发大小前置检查）。
      final bigFile = File('${root.path}/big.json');
      final sink = bigFile.openWrite();
      sink.add(List.filled(65 * 1024 * 1024, 32));
      await sink.close();
      final service = ContentImportService(
        supportDirectory: support,
        temporaryDirectory: temporary,
      );
      await expectLater(
        service.importFromFile(bigFile.path),
        throwsA(
          isA<ContentImportException>().having(
            (e) => e.message,
            'message',
            contains('64MB'),
          ),
        ),
      );
      // 小文件流程不受影响（前置检查没误伤）
      final summary = await service.importFromFile(file.path);
      expect(summary.questionCount, 2);
    });

    test('找不到文件报错', () async {
      final service = ContentImportService(
        supportDirectory: support,
        temporaryDirectory: temporary,
      );
      await expectLater(
        service.importFromFile('${root.path}/nope.json'),
        throwsA(isA<ContentImportException>()),
      );
    });
  });
}
