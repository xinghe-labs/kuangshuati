import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/features/practice/time_budget.dart';

void main() {
  group('moduleBudgetsSeconds', () {
    test('按模块题数占比分摊总时长', () {
      // 130 题 / 120 分钟：资料 20 题 → 120*20/130 = 18.46 → ceil 19 分钟。
      final budgets = moduleBudgetsSeconds(
        totalBudgetSeconds: 120 * 60,
        questionCountByModule: const {
          '常识判断': 20,
          '言语理解与表达': 40,
          '数量关系': 10,
          '判断推理': 40,
          '资料分析': 20,
        },
      );
      expect(budgets['资料分析'], (120 * 60 * 20 / 130).ceil());
      expect(budgets['言语理解与表达'], (120 * 60 * 40 / 130).ceil());
      expect(budgets.length, 5);
    });

    test('向上取整保证预算总和不少于总时长', () {
      final budgets = moduleBudgetsSeconds(
        totalBudgetSeconds: 100,
        questionCountByModule: const {'a': 1, 'b': 1, 'c': 1},
      );
      final sum = budgets.values.fold(0, (a, b) => a + b);
      expect(sum, greaterThanOrEqualTo(100));
    });

    test('总时长为 0 或题量为 0 时不分预算', () {
      expect(
        moduleBudgetsSeconds(
          totalBudgetSeconds: 0,
          questionCountByModule: const {'a': 5},
        ),
        isEmpty,
      );
      expect(
        moduleBudgetsSeconds(
          totalBudgetSeconds: 600,
          questionCountByModule: const {},
        ),
        isEmpty,
      );
    });

    test('题数为 0 的模块不分预算', () {
      final budgets = moduleBudgetsSeconds(
        totalBudgetSeconds: 600,
        questionCountByModule: const {'a': 5, 'b': 0},
      );
      expect(budgets.containsKey('b'), isFalse);
      expect(budgets['a'], 600);
    });
  });

  group('formatLimitClock', () {
    test('基本分秒与小时', () {
      expect(formatLimitClock(0), '00:00');
      expect(formatLimitClock(59), '00:59');
      expect(formatLimitClock(60), '01:00');
      expect(formatLimitClock(3725), '1:02:05');
    });

    test('负数按 0 处理', () {
      expect(formatLimitClock(-3), '00:00');
    });
  });

  group('questionLimitPresentation', () {
    test('时间充裕：正常色', () {
      final info = questionLimitPresentation(59, 60);
      expect(info.over, isFalse);
      expect(info.warn, isFalse);
      expect(info.label, '本题 00:59');
    });

    test('剩余不足三分之一：预警', () {
      expect(questionLimitPresentation(15, 60).warn, isTrue);
    });

    test('剩余不足 10 秒：预警', () {
      expect(questionLimitPresentation(9, 45).warn, isTrue);
    });

    test('超时：红色 + 超出量', () {
      final info = questionLimitPresentation(-5, 45);
      expect(info.over, isTrue);
      expect(info.label, '已超时 +00:05');
    });
  });
}
