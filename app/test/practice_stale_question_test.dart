// 题库换版后，进行中的练习里可能有题已经不存在。
// 旧行为：页面只显示一行“题目不存在”，没有 AppBar、没有返回按钮，
// 而外层 PopScope 是 canPop: false —— 用户被关在死页面里，只能杀进程。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/practice/practice_page.dart';

/// 只认得一部分题：模拟题库换版后旧题消失。
class _PartialContentRepository extends SeedContentRepository {
  _PartialContentRepository(this.known);

  final List<QuestionContent> known;

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    final byId = {for (final question in known) question.id: question};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

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
  module: '言语理解',
  stem: '题干 $id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  Future<void> pumpPractice(
    WidgetTester tester, {
    String id = 'session-stale',
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            _PartialContentRepository([
              _question('ok-1'),
              _question('ok-2'),
              _fiveOptionQuestion(),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: PracticePage(sessionId: id),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('练习中遇到失效题：要有返回和交卷出口，不能是死页面', (tester) async {
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-stale',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: [
          _question('ok-1'),
          _question('gone-1'),
          _question('ok-2'),
        ],
        revealMode: RevealMode.immediate,
        requestedCount: 3,
      );
      // 用户已经做到第 2 题（索引 1），而这题在新题库里没了。
      await database.saveProgress(
        sessionId: 'session-stale',
        currentIndex: 1,
        durationMs: 5000,
      );
    });

    await pumpPractice(tester);

    expect(find.text('这道题已随题库更新失效'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget, reason: '没有 AppBar 就没有返回/交卷入口');
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.text('交卷查看结果'), findsOneWidget);
  });

  testWidgets('失效题页面点“交卷查看结果”能真的交卷，不会卡住', (tester) async {
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-stale',
        mode: PracticeMode.sequence,
        title: '顺序练习',
        questions: [
          _question('ok-1'),
          _question('gone-1'),
          _question('ok-2'),
        ],
        revealMode: RevealMode.immediate,
        requestedCount: 3,
      );
      await database.saveProgress(
        sessionId: 'session-stale',
        currentIndex: 1,
        durationMs: 5000,
      );
    });

    await pumpPractice(tester);
    await tester.tap(find.text('交卷查看结果'));
    await tester.pumpAndSettle();
    // 弹出交卷确认框。
    expect(find.text('确认交卷'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, '确认交卷'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();

    final session = await database.sessionById('session-stale');
    expect(session?.status, SessionStatus.submitted.value);
  });

  testWidgets('五个选项的题：桌面端按 5 也能选中', (tester) async {
    await tester.runAsync(() async {
      await database.createSession(
        id: 'session-five',
        mode: PracticeMode.random,
        title: '五选项题',
        questions: [_fiveOptionQuestion()],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
    });

    await pumpPractice(tester, id: 'session-five');
    expect(find.text('选项戊'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // 选中的选项会落库；早先只绑定了 1-4，按 5 毫无反应。
    final answers = await database.answersForSession('session-five');
    expect(answers.single.selectedJson, '["E"]');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('练习记录读不出来时不是死页面，能返回首页', (tester) async {
    // 会话根本不存在（被清空/恢复备份后残留的深链接）。
    await pumpPractice(tester, id: 'session-missing', settle: false);
    expect(find.textContaining('无法打开这次练习'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget, reason: '没有 AppBar 就没有返回入口');
    expect(find.text('返回首页'), findsOneWidget);
  });
}

QuestionContent _fiveOptionQuestion() => QuestionContent(
  id: 'five-1',
  paperId: 'paper-1',
  questionNo: 1,
  sequence: 1,
  module: '常识判断',
  stem: '五个选项的题',
  options: const {'A': '选项甲', 'B': '选项乙', 'C': '选项丙', 'D': '选项丁', 'E': '选项戊'},
  correctAnswers: const {'E'},
  solution: '解析',
  searchStem: null,
  groupId: '',
);
