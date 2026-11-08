import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/home/home_page.dart';
import 'package:kuangshuati/features/practice/mock_paper.dart';

/// 随机模考组卷的纯函数：配比、缺口再分配、实际可组题数、合并顺序、时长。
void main() {
  group('moduleQuotas 按占比分配', () {
    test('真题结构：按题库占比加权，总数精确等于目标', () {
      final quotas = moduleQuotas(
        availableByModule: const {'言语': 400, '数量': 100},
        total: 13,
      );
      // 10.4 → 10（余数 0.4），2.6 → 2（余数 0.6），缺口补给余数大的数量。
      expect(quotas, {'言语': 10, '数量': 3});
      // 大块模块排前面：组卷顺序接近真题卷。
      expect(quotas.keys.toList(), ['言语', '数量']);
    });

    test('权重相同时平手按模块名稳定排序', () {
      final quotas = moduleQuotas(
        availableByModule: const {'b': 10, 'a': 10},
        total: 3,
      );
      expect(quotas, {'a': 2, 'b': 1});
    });

    test('均匀分配：各模块平均分', () {
      final quotas = moduleQuotas(
        availableByModule: const {'言语': 400, '数量': 100},
        total: 10,
        mix: RandomMockMix.even,
      );
      expect(quotas, {'言语': 5, '数量': 5});
    });

    test('零题模块不参与分配；空表或目标为 0 返回空', () {
      expect(
        moduleQuotas(availableByModule: const {'a': 0, 'b': 5}, total: 5),
        {'b': 5},
      );
      expect(moduleQuotas(availableByModule: const {}, total: 10), isEmpty);
      expect(
        moduleQuotas(availableByModule: const {'a': 5}, total: 0),
        isEmpty,
      );
    });

    test('配额允许超过模块可用量（缺口交给再分配），总数始终精确', () {
      final quotas = moduleQuotas(
        availableByModule: const {'a': 7, 'b': 7, 'c': 7},
        total: 10,
      );
      expect(quotas.values.fold(0, (sum, item) => sum + item), 10);
    });
  });

  group('nextQuotas 缺口再分配', () {
    test('按剩余可用量把缺口分给还有余量的模块', () {
      final next = nextQuotas(
        quotas: const {'言语': 10, '判断': 5},
        receivedByModule: const {'言语': 10, '判断': 2},
        availableByModule: const {'言语': 10, '判断': 3},
        target: 15,
      );
      // 已抽 12，缺 3；言语已抽满（剩余 0），判断只剩 1 可抽但配额给 3，
      // 启动器按 min(need, 可用) 实际抽 1 后进入下一轮。
      expect(next, {'判断': 5});
    });

    test('所有模块都没有余量时返回 null', () {
      final next = nextQuotas(
        quotas: const {'言语': 10, '判断': 5},
        receivedByModule: const {'言语': 10, '判断': 3},
        availableByModule: const {'言语': 10, '判断': 3},
        target: 15,
      );
      expect(next, isNull);
    });
  });

  group('achievableRandomMockCount 实际可组题数', () {
    test('题库充足时等于目标题量', () {
      expect(
        achievableRandomMockCount(
          availableByModule: const {'a': 10, 'b': 5},
          total: 13,
          mix: RandomMockMix.paperStructure,
        ),
        13,
      );
    });

    test('题库不足时返回真实可组数', () {
      expect(
        achievableRandomMockCount(
          availableByModule: const {'a': 6, 'b': 4},
          total: 13,
          mix: RandomMockMix.even,
        ),
        10,
      );
    });

    test('题库为空时返回 0', () {
      expect(
        achievableRandomMockCount(
          availableByModule: const {},
          total: 13,
          mix: RandomMockMix.even,
        ),
        0,
      );
    });
  });

  group('assembleRandomMockPaper 合并顺序', () {
    test('按模块顺序拼接，模块内保持抽题返回顺序', () {
      final paper = assembleRandomMockPaper(
        moduleOrder: const ['b', 'a'],
        receivedByModule: {
          'a': [
            _question('qa1'),
            _question('qa2'),
          ],
          'b': [_question('qb1')],
        },
      );
      expect(paper.map((item) => item.id), ['qb1', 'qa1', 'qa2']);
    });
  });

  group('randomMockDurationSeconds 时长折算', () {
    test('60 秒/题，向上取整到 5 分钟', () {
      expect(randomMockDurationSeconds(130), 7800); // 130 分钟
      expect(randomMockDurationSeconds(105), 6300); // 105 分钟
      expect(randomMockDurationSeconds(20), 1200); // 20 分钟
      expect(randomMockDurationSeconds(1), 300); // 1 分钟
      expect(randomMockDurationSeconds(0), 0);
    });
  });

  testWidgets('首页随机模考弹层：预览真实可组题数，题库不足时如实提示', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            SeedContentRepository(),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    await tester.tap(find.text('随机模考'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();

    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) {
          final widget = element.widget as Text;
          return widget.data ?? widget.textSpan?.toPlainText() ?? '';
        })
        .toList();
    final joined = texts.join('\n');
    // 演示题库 12 题，目标 130 组不满，必须如实提示，而不是假装能组 130 题。
    expect(
      joined.contains('题库共 12 题，本次预计组成 12 题（目标 130）'),
      isTrue,
      reason: '弹层实际文本：\n$joined',
    );
    // 按钮显示真实题数与折算时长：12 题 × 60 秒 = 720 秒，取整到 5 分钟 = 15:00。
    expect(joined.contains('开始 · 预计 12 题 · 15:00'), isTrue);
    // 两个配比选项都在。
    expect(joined.contains('真题结构'), isTrue);
    expect(joined.contains('均匀分配'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}

QuestionContent _question(String id) => QuestionContent(
      id: id,
      paperId: 'p',
      questionNo: 1,
      sequence: 1,
      module: '言语理解',
      stem: '题干',
      options: const {'A': '甲'},
      correctAnswers: const {'A'},
      solution: '解析',
    );
