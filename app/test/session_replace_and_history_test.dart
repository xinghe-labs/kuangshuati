// 回归：
// 1) 有未完成练习时开始新练习必须先确认（requirements-discovery Q6），
//    早先 createSession 直接把旧会话标成 abandoned，用户点一下就把进度丢了。
// 2) 统计页「最近练习」保留每一组已交卷的成绩，离开结果页后仍可回看。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/home/home_page.dart';
import 'package:kuangshuati/features/stats/stats_page.dart';

class _StubContentRepository extends SeedContentRepository {
  _StubContentRepository(this.questions);

  final List<QuestionContent> questions;

  @override
  List<QuestionContent> randomQuestions(int count, {String? module}) =>
      questions.take(count).toList();

  @override
  List<QuestionContent> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  }) => questions.take(limit).toList();

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) => const [];

  @override
  Future<ContentImage?> imageWithSize(String assetId) async => null;

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};
}

QuestionContent _question(String id) => QuestionContent(
  id: id,
  paperId: 'paper-1',
  questionNo: 1,
  sequence: 1,
  module: '判断推理',
  stem: '题干 $id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

Future<void> _settle(WidgetTester tester, [int ms = 300]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
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
      path: '/result/:id',
      builder: (context, state) =>
          Scaffold(body: Text('RESULT ${state.pathParameters['id']}')),
    ),
  ],
);

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('有未完成练习时点「随机 20 题」：先弹确认，旧练习不会被静默作废', (tester) async {
    final questions = [for (var i = 0; i < 5; i++) _question('q$i')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-old',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 5,
      );
      for (final question in questions.take(3)) {
        await database.saveAnswer(
          sessionId: 'session-old',
          questionId: question.id,
          selected: {'A'},
          submitted: true,
          isCorrect: true,
          durationMs: 4000,
          module: question.module,
        );
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _StubContentRepository(questions),
          ),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: _router(),
        ),
      ),
    );
    await _settle(tester, 500);
    await tester.pumpAndSettle();
    expect(find.text('继续练习'), findsOneWidget);

    await tester.tap(find.text('随机 20 题'));
    await _settle(tester, 500);
    await tester.pumpAndSettle();

    // 必须弹确认框，并且说明旧练习已答多少。
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('还有一组练习没做完'), findsOneWidget);
    final dialogText = find
        .descendant(of: find.byType(AlertDialog), matching: find.byType(Text))
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .join(' | ');
    expect(dialogText.contains('已答 3 / 5 题'), isTrue, reason: dialogText);

    // 用户没做选择之前，旧练习必须还是 active。
    final old = await database.sessionById('session-old');
    expect(old?.status, SessionStatus.active.value);

    // 选「返回当前练习」：跳到那组练习，旧会话保持 active，不新建会话。
    await tester.tap(find.text('返回当前练习'));
    await _settle(tester, 400);
    await tester.pumpAndSettle();
    expect(find.text('PRACTICE session-old'), findsOneWidget);
    final stillOld = await database.sessionById('session-old');
    expect(stillOld?.status, SessionStatus.active.value);
    final sessions = await tester.runAsync(
      () => database.watchRecentSessions().first,
    );
    expect(sessions?.where((s) => s.id != 'session-old'), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('选「结束旧练习并开始」才会真的替换', (tester) async {
    final questions = [for (var i = 0; i < 5; i++) _question('q$i')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-old',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 5,
      );
      await database.saveAnswer(
        sessionId: 'session-old',
        questionId: 'q0',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 1000,
        module: '判断推理',
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _StubContentRepository(questions),
          ),
        ],
        child: MaterialApp.router(
          theme: buildAppTheme(),
          routerConfig: _router(),
        ),
      ),
    );
    await _settle(tester, 500);
    await tester.pumpAndSettle();

    await tester.tap(find.text('随机 20 题'));
    await _settle(tester, 500);
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束旧练习并开始'));
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final old = await database.sessionById('session-old');
    expect(old?.status, SessionStatus.abandoned.value);
    final active = await database.latestActiveSession();
    expect(active, isNotNull);
    expect(active!.id, isNot('session-old'));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('统计页「最近练习」列出已交卷的练习，可以回看成绩', (tester) async {
    final questions = [_question('q1'), _question('q2')];
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-done',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: questions,
        revealMode: RevealMode.immediate,
        requestedCount: 2,
      );
      await database.saveAnswer(
        sessionId: 'session-done',
        questionId: 'q1',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 4000,
        module: '判断推理',
      );
      await database.saveAnswer(
        sessionId: 'session-done',
        questionId: 'q2',
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 4000,
        module: '判断推理',
      );
      await database.finalizeSession(
        sessionId: 'session-done',
        questionLookup: {for (final q in questions) q.id: q},
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _StubContentRepository(questions),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: StatsPage()),
        ),
      ),
    );
    await _settle(tester, 600);
    await tester.pumpAndSettle();

    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => (element.widget as Text).data ?? '')
        .toList();
    expect(texts.any((text) => text.contains('最近练习')), isTrue);
    expect(
      texts.any((text) => text.contains('2/2 题') && text.contains('正确率 50%')),
      isTrue,
      reason: texts.join(' | '),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
