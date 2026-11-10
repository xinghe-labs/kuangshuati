import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/features/content/content_import_service.dart';

/// 实跑 App 侧 bank 校验器（parseBankJson，与本地导入同一解析路径），
/// 对数据侧交付的全部 bank JSON 做导入级验证。
void main() {
  final banksDir = _configuredBanksDir();
  if (banksDir == null) {
    test('bank 导入校验（需要 KSQ_BANKS_DIR）', () {
      markTestSkipped('未设置 KSQ_BANKS_DIR，跳过数据侧导入校验');
    });
  } else {
    _checkDeliveredBanks(banksDir);
  }

  _v2FormatTests();
}

/// 数据侧交付的 bank JSON 是私有数据，不在仓库里，所以目录由环境变量指路：
///   KSQ_BANKS_DIR=/path/to/banks flutter test test/bank_import_test.dart
/// 没设或目录不存在时整组跳过——公开仓的 CI 就是这种情况。
/// （这里曾经硬编码过一个本机绝对路径，导致在 Linux CI 上整个文件加载失败。）
Directory? _configuredBanksDir() {
  final configured = Platform.environment['KSQ_BANKS_DIR'];
  if (configured == null || configured.isEmpty) return null;
  final dir = Directory(configured);
  return dir.existsSync() ? dir : null;
}

void _checkDeliveredBanks(Directory banksDir) {
  final bankFiles = banksDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.bank.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('bank 文件数量 ≥ 8（存量题库不缩水）', () {
    expect(
      bankFiles.length,
      greaterThanOrEqualTo(8),
      reason: bankFiles.map((f) => f.path).join('\n'),
    );
  });

  for (final file in bankFiles) {
    test('导入校验: ${file.uri.pathSegments.last}', () {
      final source = file.readAsStringSync();
      final bank = parseBankJson(source);

      expect(bank.contentVersion, isNotEmpty);
      expect(bank.papers, isNotEmpty);

      var questionCount = 0;
      var noAnswer = 0;
      for (final paper in bank.papers) {
        expect(paper.questions, isNotEmpty, reason: 'paper ${paper.id} 无题');
        for (final q in paper.questions) {
          questionCount++;
          if (q.answers.isEmpty) noAnswer++;
          // v2：自评题 options/answers 双空；不允许单空（校验器已拦，这里再验一遍）。
          if (q.options.isEmpty) {
            expect(q.answers, isEmpty, reason: '${q.id} options 空但 answers 非空');
          }
        }
      }
      // ignore: avoid_print
      print(
        '${file.uri.pathSegments.last}: ${bank.papers.length} 卷, '
        '$questionCount 题, 自评题 $noAnswer',
      );
      expect(questionCount, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

/// 格式校验不依赖外部数据，任何环境都跑。
void _v2FormatTests() {
  test('v2 自评题：双省略合法', () {
    final v2Bank = '{"format":"kuangshuati-bank","formatVersion":2,'
        '"name":"自评题测试","contentVersion":"1.0.0+1","images":{},'
        '"papers":[{"id":"p1","title":"卷一","year":2024,"durationMinutes":60,'
        '"questions":['
        '{"id":"q-self","type":"单选题","module":"数学","stem":"求解方程 x^2 = 4",'
        '"solution":"参考答案"},'
        '{"id":"q-choice","type":"单选题","module":"数学","stem":"1+1 = ?",'
        '"options":{"A":"2","B":"3"},"answer":["A"],"solution":"略"}'
        ']}]}';
    final bank = parseBankJson(v2Bank);
    final selfAssessed = bank.papers.first.questions.first;
    expect(selfAssessed.options, isEmpty);
    expect(selfAssessed.answers, isEmpty);
    final choice = bank.papers.first.questions[1];
    expect(choice.options, isNotEmpty);
    expect(choice.answers, ['A']);
  });

  test('v2 自评题：只省 options 拒绝', () {
    final badBank = '{"format":"kuangshuati-bank","formatVersion":2,'
        '"name":"坏数据","contentVersion":"1.0.0+1","images":{},'
        '"papers":[{"id":"p1","title":"卷一","year":2024,"durationMinutes":60,'
        '"questions":[{"id":"q1","type":"单选题","module":"数学","stem":"题干",'
        '"answer":["A"]}]}]}';
    expect(
      () => parseBankJson(badBank),
      throwsA(isA<ContentImportException>()),
    );
  });

  test('formatVersion=3 拒绝', () {
    const v3Bank = '{"format":"kuangshuati-bank","formatVersion":3,'
        '"name":"未来格式","contentVersion":"1.0.0+1","images":{},"papers":[]}';
    expect(() => parseBankJson(v3Bank), throwsA(isA<ContentImportException>()));
  });
}
