// 按模块刷题：模块排序、优先未做过的题、首页区块。
//
// 这几件事都能悄悄坏掉而不报错：
// - 排序错了 → 首页「最弱」指着用户最熟的模块；
// - 优先未做过没生效 → 每次点同一个模块都在重刷同一批题；
// - 题不够时静默掺入做过的题而不提示 → 用户以为在练新题。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/full_content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/domain/module_stats.dart';
import 'package:kuangshuati/features/home/home_page.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

ModuleStat _stat(String module, int answered, int correct) => ModuleStat(
  module: module,
  answeredCount: answered,
  correctCount: correct,
  durationMs: 0,
  updatedAt: 0,
);

QuestionContent _question(String id, String module) => QuestionContent(
  id: id,
  paperId: 'p',
  questionNo: 1,
  sequence: 1,
  module: module,
  stem: '题干$id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
);

class _StubRepository extends SeedContentRepository {
  _StubRepository(this.byModule);

  final Map<String, List<QuestionContent>> byModule;

  List<QuestionContent> get _all => [
    for (final list in byModule.values) ...list,
  ];

  @override
  Map<String, int> moduleCounts() => {
    for (final entry in byModule.entries) entry.key: entry.value.length,
  };

  @override
  List<QuestionContent> randomQuestions(
    int count, {
    String? module,
    Iterable<String> excludeIds = const [],
  }) {
    final pool = (module == null ? _all : (byModule[module] ?? const []))
        .where((item) => !excludeIds.contains(item.id))
        .toList();
    return pool.take(count).toList(growable: false);
  }

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) => [
    for (final id in ids) ..._all.where((item) => item.id == id),
  ];
}

GoRouter _router() => GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(
      path: '/home',
      builder: (context, state) => const Scaffold(body: HomePage()),
    ),
    GoRoute(
      path: '/practice/:id',
      builder: (context, state) =>
          Scaffold(body: Text('PRACTICE ${state.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/stats',
      builder: (context, state) => const Scaffold(body: Text('STATS')),
    ),
  ],
);

/// 拆树并排空 drift 的 stream 定时器。
///
/// 必须在用例体的 finally 里调：断言失败时用例体剩下的代码不会执行，
/// 而 flutter_test 的不变式检查（“Timer is still pending”）在 tearDown 之前跑，
/// 残留定时器会让本用例报错、还会把同文件下一个用例一起卡死。
Future<void> _disposeHome(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

/// 真实时间跑一会儿再 pump：首页有 FutureProvider 和真实 IO。
Future<void> _settle(WidgetTester tester, [int ms = 400]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
}

Future<void> _pumpHome(
  WidgetTester tester,
  AppDatabase database,
  Map<String, List<QuestionContent>> byModule,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(_StubRepository(byModule)),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: _router(),
      ),
    ),
  );
  await _settle(tester);
  await _settle(tester, 300);
}

/// 造一批「以前做过」的记录，并把那场练习标成交卷状态：
/// 留在 active 状态的话，新练习会先弹「还有一组练习没做完」的确认框。
Future<void> _seedAnswered(
  AppDatabase database,
  QuestionContent first,
  List<String> answeredIds,
) async {
  await database.createSession(
    id: 'old',
    mode: PracticeMode.custom,
    title: '旧练习',
    questions: [first],
    revealMode: RevealMode.immediate,
  );
  for (final id in answeredIds) {
    await database.saveAnswer(
      sessionId: 'old',
      questionId: id,
      selected: const {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 1000,
      module: first.module,
    );
  }
  await (database.update(
    database.practiceSessions,
  )..where((row) => row.id.equals('old'))).write(
    PracticeSessionsCompanion(status: Value(SessionStatus.submitted.value)),
  );
}

Future<void> _seedModuleStats(AppDatabase database) async {
  // 判断推理 40 题答对 20 → 50%，最弱；言语理解 90%，不算弱项。
  for (final entry in {
    '判断推理': _stat('判断推理', 40, 20),
    '言语理解': _stat('言语理解', 30, 27),
  }.entries) {
    await database
        .into(database.moduleStats)
        .insertOnConflictUpdate(
          ModuleStatsCompanion.insert(
            module: entry.key,
            answeredCount: Value(entry.value.answeredCount),
            correctCount: Value(entry.value.correctCount),
            durationMs: const Value(0),
            updatedAt: 0,
          ),
        );
  }
}

List<String> _texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? '')
    .toList();

Future<Set<String>> _sessionQuestionIds(
  WidgetTester tester,
  AppDatabase database,
) async {
  final label = tester.widget<Text>(find.textContaining('PRACTICE ')).data!;
  final sessionId = label.replaceFirst('PRACTICE ', '');
  final rows = await database.sessionQuestionRows(sessionId);
  return rows.map((row) => row.questionId).toSet();
}

void main() {
  group('模块排序', () {
    test('弱项在前、样本不足其次、没练过的最后', () {
      final stats = {
        '言语理解': _stat('言语理解', 30, 27), // 90%
        '判断推理': _stat('判断推理', 40, 20), // 50% → 最弱
        '资料分析': _stat('资料分析', 5, 5), // 样本不足
        '常识判断': _stat('常识判断', 0, 0), // 没数据
      };
      final counts = {'言语理解': 300, '判断推理': 200, '资料分析': 100, '常识判断': 400};
      final ordered = counts.keys.toList()
        ..sort((a, b) => compareModulesForPractice(a, b, stats, counts));
      expect(ordered, ['判断推理', '言语理解', '资料分析', '常识判断']);
      expect(weakestModule(stats.values.toList())?.module, '判断推理');
    });

    test('没作答过的模块不会被当成最弱', () {
      final stats = {'判断推理': _stat('判断推理', 0, 0)};
      expect(weakestModule(stats.values.toList()), isNull);
      expect(moduleAccuracy(stats['判断推理']!), isNull);
    });
  });

  group('优先没做过的题', () {
    test('真实题库：排除已做过的题，且不拆开材料题组', () async {
      final file = File('assets/content/content.sqlite');
      if (!file.existsSync()) {
        markTestSkipped('未提供题库文件，跳过真实题库校验');
        return;
      }
      final content = FullContentRepository.forTesting(
        sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly),
      );
      addTearDown(content.close);

      // 找一组带 groupId 的材料题，把其中一道标成「做过」：
      // 整组都不该再出现，否则材料会只显示一半。
      final sample = await content.randomQuestions(400, module: '资料分析');
      final grouped = sample.where((item) => item.groupId.isNotEmpty).toList();
      expect(grouped, isNotEmpty, reason: '资料分析应当有材料题组');
      final groupId = grouped.first.groupId;
      final groupIds =
          (await content.questionsByIds(grouped.map((item) => item.id)))
              .where((item) => item.groupId == groupId)
              .map((item) => item.id)
              .toSet();
      expect(groupIds.length, greaterThan(1), reason: '这一组应当有多道题');

      final picked = await content.randomQuestions(
        60,
        module: '资料分析',
        excludeIds: {groupIds.first},
      );
      expect(
        picked.any((item) => groupIds.contains(item.id)),
        isFalse,
        reason: '材料题组里有题做过，整组都不该再抽到',
      );
      expect(
        picked.every((item) => item.module == '资料分析'),
        isTrue,
        reason: '按模块抽题不能串模块',
      );
    });
  });

  group('首页模块区块', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    testWidgets('弱项排第一并标「最弱」，点一下只给这个模块没做过的题', (tester) async {
      try {
        final byModule = {
          '判断推理': [for (var i = 1; i <= 25; i++) _question('pd$i', '判断推理')],
          '言语理解': [for (var i = 1; i <= 3; i++) _question('yy$i', '言语理解')],
        };

        await tester.runAsync(() async {
          await _seedModuleStats(database);
          await _seedAnswered(database, byModule['判断推理']!.first, [
            'pd1',
            'pd2',
          ]);
        });

        await _pumpHome(tester, database, byModule);

        expect(find.text('按模块刷题'), findsOneWidget);
        final texts = _texts(tester);
        final weakestIndex = texts.indexOf('最弱');
        final weakModuleIndex = texts.indexOf('判断推理');
        expect(weakModuleIndex, greaterThanOrEqualTo(0));
        // 「最弱」挂在判断推理那张卡上，且它排在最前。
        expect(weakModuleIndex, lessThan(weakestIndex));
        expect(weakestIndex, lessThan(texts.indexOf('言语理解')));
        expect(texts.where((text) => text == '最弱').length, 1);
        // 没作答过的模块不能挂「最弱」：言语理解有 90% 的正确率。
        expect(texts.any((text) => text.contains('正确率 90%')), isTrue);

        await tester.tap(find.text('判断推理'));
        await _settle(tester, 500);
        // 不用 pumpAndSettle：首页下半区的加载转圈是无限动画，永远 settle 不了。
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final ids = await tester.runAsync(
          () => _sessionQuestionIds(tester, database),
        );
        expect(ids!.length, 20);
        expect(
          ids.contains('pd1') || ids.contains('pd2'),
          isFalse,
          reason: '做过的 pd1/pd2 不该再出现',
        );
        expect(
          ids.every((id) => id.startsWith('pd')),
          isTrue,
          reason: '按模块练习不能掺进言语理解的题',
        );
        // 题够的时候不该出现回退提示。
        expect(_texts(tester).any((text) => text.contains('未做过的题不足')), isFalse);
      } finally {
        await _disposeHome(tester);
      }
    });

    testWidgets('模块题量不够时回退掺入做过的题，并明确告诉用户', (tester) async {
      try {
        final byModule = {
          '判断推理': [for (var i = 1; i <= 5; i++) _question('pd$i', '判断推理')],
          '言语理解': [for (var i = 1; i <= 3; i++) _question('yy$i', '言语理解')],
        };

        await tester.runAsync(() async {
          await _seedModuleStats(database);
          await _seedAnswered(database, byModule['判断推理']!.first, [
            'pd1',
            'pd2',
          ]);
        });

        await _pumpHome(tester, database, byModule);
        await tester.tap(find.text('判断推理'));
        await _settle(tester, 500);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final ids = await tester.runAsync(
          () => _sessionQuestionIds(tester, database),
        );
        expect(ids!.length, 5, reason: '未做过的只有 3 道，回退后应当凑满 5 道');
        expect(
          _texts(tester).any((text) => text.contains('未做过的题不足 20 道')),
          isTrue,
          reason: '掺入了做过的题必须明说，否则用户以为在练新题',
        );
      } finally {
        await _disposeHome(tester);
      }
    });
  });
}
