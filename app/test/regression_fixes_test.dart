import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/app.dart' show effectiveTextScale;
import 'package:kuangshuati/domain/models.dart';
import 'package:kuangshuati/features/practice/practice_page.dart'
    show optionTextRepeatsLetter;

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

  test('字号合并取较大值：设置里选“小”不会被系统大字号拖回去', () {
    // 之前是相乘：1.3 × 0.9 = 1.17，用户选了“小”字反而更大，设置项形同虚设。
    expect(effectiveTextScale(0.9, 1.3), 1.3);
    expect(effectiveTextScale(0.9, 1.0), 1.0);
    // 选“大”时尊重用户选择，不被系统小字号压回去。
    expect(effectiveTextScale(1.15, 1.0), 1.15);
    expect(effectiveTextScale(1.15, 0.85), 1.15);
    // 上下限仍然生效，避免极端组合把布局撑破。
    expect(effectiveTextScale(3.0, 3.0), 1.6);
    expect(effectiveTextScale(0.1, 0.1), 0.85);
  });
}
