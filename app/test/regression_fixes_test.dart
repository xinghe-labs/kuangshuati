import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/core/theme/app_theme.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

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
    expect(
      review.where((item) => item.questionId == multi.id),
      isEmpty,
    );
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
}
