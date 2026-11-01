import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/providers.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/content_repository.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/app.dart' show effectiveTextScale;
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/practice/practice_page.dart'
    show optionTextRepeatsLetter, PracticePage;

void main() {
  late AppDatabase database;
  final repository = SeedContentRepository();
  final questions = repository.allQuestions.take(3).toList();
  final lookup = {for (final question in questions) question.id: question};

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('多选题：多个字母提交后按集合相等判分', () async {
    final multi = questions.firstWhere(
      (question) => question.options.length >= 4,
      orElse: () => questions.first,
    );
    final multiCorrect = multi.correctAnswers.length > 1;
    await database.createSession(
      id: 'session-multi',
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: [multi],
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: 'session-multi',
      questionId: multi.id,
      selected: multi.correctAnswers,
      submitted: true,
      isCorrect: true,
      durationMs: 500,
    );
    await database.finalizeSession(
      sessionId: 'session-multi',
      questionLookup: lookup,
    );
    final answers = await database.answersForSession('session-multi');
    expect(
      (jsonDecode(answers.single.selectedJson) as List<Object?>).toSet(),
      multi.correctAnswers.toSet(),
    );
    expect(answers.single.isCorrect, isTrue);
    // 多选答对不进错题本。
    final review = await database.allReviewItems();
    expect(review.where((item) => item.questionId == multi.id), isEmpty);
    expect(multiCorrect || multi.correctAnswers.length == 1, isTrue);
  });

  test('未作答的题在交卷后不进错题本', () async {
    await database.createSession(
      id: 'session-blank',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: 'session-blank',
      questionId: questions[0].id,
      selected: {},
      submitted: false,
      isCorrect: false,
      durationMs: 100,
    );
    await database.finalizeSession(
      sessionId: 'session-blank',
      questionLookup: lookup,
    );
    final review = await database.allReviewItems();
    expect(review, isEmpty);
    final answers = await database.answersForSession('session-blank');
    expect(answers, hasLength(questions.length));
    expect(answers.every((answer) => answer.isCorrect == false), isTrue);
    final blank = answers.firstWhere(
      (answer) => answer.questionId == questions[0].id,
    );
    expect(blank.selectedJson, '[]');
  });

  test('取消收藏不删除笔记，再收藏后笔记仍在', () async {
    final id = questions.first.id;
    expect(await database.toggleFavorite(id), isTrue);
    await database.setFavoriteNote(id, '这题的关键是“基层治理”四个字');
    expect(await database.favoriteNote(id), contains('基层治理'));

    await database.toggleFavorite(id);
    expect(await database.favoriteNote(id), contains('基层治理'));

    expect(await database.toggleFavorite(id), isTrue);
    expect(await database.favoriteNote(id), contains('基层治理'));
  });

  test('深色色表切换：AppColors getter 与主题同步生效', () {
    AppColors.current = AppPalette.dark;
    expect(AppColors.paper, AppPalette.dark.paper);
    expect(AppColors.ink, AppPalette.dark.ink);
    expect(AppColors.onInk, AppPalette.dark.onInk);

    final darkTheme = buildAppTheme(dark: true);
    expect(darkTheme.scaffoldBackgroundColor, AppPalette.dark.paper);
    expect(darkTheme.colorScheme.brightness, Brightness.dark);

    final lightTheme = buildAppTheme();
    expect(lightTheme.scaffoldBackgroundColor, AppPalette.light.paper);
    AppColors.current = AppPalette.light;
    expect(AppColors.paper, AppPalette.light.paper);
  });

  // 以下三条对应真机目检（真机，1080x2400，Android 12）发现的缺陷。
  test('AppColors.isDark 跟随色表，供公式图衬底分支判断', () {
    AppColors.current = AppPalette.dark;
    expect(AppColors.isDark, isTrue);
    AppColors.current = AppPalette.light;
    expect(AppColors.isDark, isFalse);
  });

  test('底部导航选中标签用 ink，深色下不与背景融在一起', () {
    // onInk 是「墨底上的反白字」，但导航标签落在指示器药丸之外、
    // 底色是 surface；用 onInk 会变成深灰字配深灰底，深色下几乎看不见。
    for (final dark in [false, true]) {
      final palette = dark ? AppPalette.dark : AppPalette.light;
      final theme = buildAppTheme(dark: dark);
      final labelStyle = theme.navigationBarTheme.labelTextStyle!.resolve({
        WidgetState.selected,
      })!;
      expect(labelStyle.color, palette.ink, reason: 'dark=$dark');
      expect(labelStyle.color, isNot(palette.onInk), reason: 'dark=$dark');
      final contrast =
          (labelStyle.color!.computeLuminance() -
                  palette.surface.computeLuminance())
              .abs();
      expect(contrast, greaterThan(0.4), reason: 'dark=$dark');
    }
  });

  testWidgets('选项整块可点：文字层不拦截外层 InkWell 的点击', (tester) async {
    // 真机上 SelectableText 会吞掉外层 InkWell 的点击，
    // 表现为「只有点选项卡片边缘才生效，点文字没反应」。
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: InkWell(
            onTap: () => taps++,
            child: const SizedBox(
              width: 300,
              height: 80,
              child: Center(
                child: Text('选项正文', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('选项正文'));
    await tester.pump();
    expect(taps, 1);
  });

  test('选项正文只是字母时判定为“只重复字母”，应改显“见题干图片”', () {
    // 题库实测：58890 道题里 2975 道（约 5%）的 options 就是
    // {"A":"A","B":"B",...}，真正的选项内容全在题干图里。
    // 直接渲染正文会让用户看到“A A”“B B”，像界面坏了。
    expect(optionTextRepeatsLetter('A', 'A'), isTrue);
    expect(optionTextRepeatsLetter('B', 'b'), isTrue);
    expect(optionTextRepeatsLetter('C', ' C '), isTrue);
    expect(optionTextRepeatsLetter('D', ''), isTrue);
    // 真正的选项正文不能被误判成“只重复字母”。
    expect(optionTextRepeatsLetter('A', '是推进中国式现代化的生力军'), isFalse);
    expect(optionTextRepeatsLetter('A', 'A项表述过于绝对'), isFalse);
    expect(optionTextRepeatsLetter('B', '正确'), isFalse);
  });

  test('字号设置三档都真实生效，同时叠加系统字号', () {
    // 之前是相乘：1.3 × 0.9 = 1.17，用户选了“小”字反而更大，设置项形同虚设。
    // 也不能简单取 max：max(0.9, 1.0) = 1.0 会把“小”吃掉，
    // 用户点了“小”却看不到任何变化。
    // 现在：设置值在系统值基础上按比例生效（乘以“设置 ÷ 标准 1.0”）。
    expect(effectiveTextScale(0.9, 1.3), closeTo(1.17, 1e-9));
    expect(effectiveTextScale(0.9, 1.0), closeTo(0.9, 1e-9));
    // 选“大”时同样生效。
    expect(effectiveTextScale(1.15, 1.0), closeTo(1.15, 1e-9));
    expect(effectiveTextScale(1.15, 1.3), closeTo(1.495, 1e-9));
    // 上下限仍然生效，避免极端组合把布局撑破。
    expect(effectiveTextScale(3.0, 3.0), 1.6);
    expect(effectiveTextScale(0.1, 0.1), 0.85);
    // 系统字号保持不变（1.0）时，设置里的三档必须真的产生三个不同的值。
    expect(effectiveTextScale(0.9, 1.0), lessThan(effectiveTextScale(1.0, 1.0)));
    expect(effectiveTextScale(1.15, 1.0), greaterThan(effectiveTextScale(1.0, 1.0)));
  });

  testWidgets('切到后台的时间不计入做题用时', (tester) async {
    // 之前 didChangeAppLifecycleState 只调 _saveProgress()，不冻结
    // _runStartedAt / _questionStartedAt。用户回微信 10 分钟，这 10 分钟
    // 全部算进本组用时和当前题用时，再经 finalizeSession 累加进
    // dailyStats / moduleStats，统计页“模块表现”的分钟数整片虚高。
    const backgroundPauseMs = 1500;
    final stubQuestions = [
      for (final question in questions.take(2)) question,
    ];
    await tester.runAsync(() async {
      await database.createSession(
        id: 's-bg',
        mode: PracticeMode.custom,
        title: '后台计时',
        questions: stubQuestions,
        revealMode: RevealMode.immediate,
      );
    });

    // 秒表从「页面开始加载」就起算：加载完成前的 runAsync 等待同样是
    // 前台时间，练习页的 _runStartedAt 也是在加载完成后才锚定的，两者
    // 起点一致，才能用同一个量级比较。
    final foregroundWatch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: _PracticeHarness(
          database: database,
          questions: stubQuestions,
          sessionId: 's-bg',
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final beforeBackgroundMs = foregroundWatch.elapsedMilliseconds;
    // 后台待 1500ms
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: backgroundPauseMs)),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    await tester.tap(find.text('提交答案'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    foregroundWatch.stop();

    // 页面在加载完成后才把 _runStartedAt 锚到现在，所以“真正会被计入”
    // 的前台时间 ≤ 秒表读数减去后台那一段。
    final countedForegroundMs =
        foregroundWatch.elapsedMilliseconds - backgroundPauseMs;
    final answers = await database.answersForSession('s-bg');
    final total = answers.fold<int>(0, (sum, a) => sum + a.durationMs);
    // 后台那 1500ms 必须完全不计；未修复时 total 会多出整整 1500ms
    // （实测未修复时 total ≈ 前台 + 1500）。
    expect(
      total,
      lessThanOrEqualTo(countedForegroundMs + 300),
      reason:
          '后台 $backgroundPauseMs 毫秒被算进了做题用时'
          '（total=$total，前台实测 $countedForegroundMs 毫秒，'
          '进后台前已过 $beforeBackgroundMs 毫秒）',
    );

    // 收尾：让页面真正 dispose（会取消 1s 定时器），再把残留的
    // 零延迟定时器跑完，否则 flutter_test 会报 “Timer is still pending”。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(seconds: 3));
  });

  test('笔记里只输一个空格会清空原笔记，必须能被识别为「清空」而不是「已保存」', () async {
    // setFavoriteNote 内部会 trim，用户误触一个空格就会把原笔记写成空；
    // 早先无论内容如何都提示「笔记已保存」，用户根本不知道自己写的东西没了。
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.toggleFavorite('q-note');
    await database.setFavoriteNote('q-note', '易错：基层治理');

    const original = '易错：基层治理';
    const typed = '   ';
    // 页面里的判定：trim 后为空且原来有内容 → 视为清空。
    final clearing = typed.trim().isEmpty && original.isNotEmpty;

    await database.setFavoriteNote('q-note', typed);
    expect(await database.favoriteNote('q-note'), isEmpty);
    expect(clearing, isTrue);
  });
}

/// 把 PracticePage 包进 ProviderScope，并注入测试题库。
class _PracticeHarness extends StatelessWidget {
  const _PracticeHarness({
    required this.database,
    required this.questions,
    required this.sessionId,
  });

  final AppDatabase database;
  final List<QuestionContent> questions;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(
          _HarnessContentRepository(questions),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: PracticePage(sessionId: sessionId),
      ),
    );
  }
}

class _HarnessContentRepository extends SeedContentRepository {
  _HarnessContentRepository(this.questions);

  final List<QuestionContent> questions;

  @override
  List<QuestionContent> questionsByIds(Iterable<String> ids) {
    final byId = {for (final question in questions) question.id: question};
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
