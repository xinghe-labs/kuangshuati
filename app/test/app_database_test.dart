import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/content/seed_content_repository.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

void main() {
  late AppDatabase database;
  final repository = SeedContentRepository();
  final questions = repository.allQuestions.take(2).toList();
  final lookup = {for (final question in questions) question.id: question};

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('submits answers, updates review and builds actionable stats', () async {
    await database.createSession(
      id: 'session-1',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      revealMode: RevealMode.immediate,
    );
    await database.saveProgress(
      sessionId: 'session-1',
      currentIndex: 1,
      durationMs: 1200,
    );
    await database.saveAnswer(
      sessionId: 'session-1',
      questionId: questions[0].id,
      selected: questions[0].correctAnswers,
      submitted: true,
      isCorrect: true,
      durationMs: 800,
    );
    await database.saveAnswer(
      sessionId: 'session-1',
      questionId: questions[1].id,
      selected: {'A'},
      submitted: true,
      isCorrect: false,
      durationMs: 400,
      uncertain: true,
    );

    await database.finalizeSession(
      sessionId: 'session-1',
      questionLookup: lookup,
    );

    final session = await database.sessionById('session-1');
    expect(session?.status, SessionStatus.submitted.value);
    expect(session?.currentIndex, 1);
    expect(session?.durationMs, 1200);

    final answers = await database.answersForSession('session-1');
    expect(answers, hasLength(2));
    expect(answers.every((answer) => answer.submitted), isTrue);
    expect(
      answers
          .firstWhere((answer) => answer.questionId == questions[1].id)
          .uncertain,
      isTrue,
    );

    final reviews = await database.allReviewItems();
    expect(reviews, hasLength(1));
    expect(reviews.single.questionId, questions[1].id);
    expect(reviews.single.stage, 0);
    expect(reviews.single.wrongCount, 1);

    final daily = await database.watchDailyStats().first;
    expect(daily.single.answeredCount, 2);
    expect(daily.single.correctCount, 1);
    expect(daily.single.sessionsCount, 1);

    final modules = await database.watchModuleStats().first;
    expect(modules.fold<int>(0, (sum, item) => sum + item.answeredCount), 2);
    expect(modules.fold<int>(0, (sum, item) => sum + item.correctCount), 1);
  });

  test('advances a wrong answer through five successful reviews', () async {
    final question = questions.first;
    final one = [question];
    final oneLookup = {question.id: question};

    await database.createSession(
      id: 'wrong',
      mode: PracticeMode.sequence,
      title: '顺序练习',
      questions: one,
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: 'wrong',
      questionId: question.id,
      selected: {'A'},
      submitted: true,
      isCorrect: false,
      durationMs: 100,
    );
    await database.finalizeSession(
      sessionId: 'wrong',
      questionLookup: oneLookup,
    );

    for (var round = 1; round <= 5; round++) {
      final id = 'review-$round';
      await database.createSession(
        id: id,
        mode: PracticeMode.wrong,
        title: '错题复习',
        questions: one,
        revealMode: RevealMode.immediate,
      );
      await database.saveAnswer(
        sessionId: id,
        questionId: question.id,
        selected: question.correctAnswers,
        submitted: true,
        isCorrect: true,
        durationMs: 100,
      );
      await database.finalizeSession(sessionId: id, questionLookup: oneLookup);
    }

    final review = (await database.allReviewItems()).single;
    expect(review.stage, 4);
    expect(review.mastered, isTrue);
    expect(review.nextReviewAt, isNull);
  });

  test('favorites support notes and removal', () async {
    const questionId = 'q-2026n-01';
    expect(await database.isFavorite(questionId), isFalse);
    expect(await database.toggleFavorite(questionId), isTrue);
    await database.setFavoriteNote(questionId, '先判断题型');
    expect(await database.favoriteNote(questionId), '先判断题型');
    expect(await database.toggleFavorite(questionId), isFalse);
    expect(await database.isFavorite(questionId), isFalse);
  });
}
