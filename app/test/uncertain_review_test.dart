import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

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

Future<String> _createSession(
  AppDatabase database,
  List<QuestionContent> questions, {
  String? title,
}) async {
  final id = 'session-${questions.map((q) => q.id).join('-')}-$title';
  await database.createSession(
    id: id,
    mode: PracticeMode.custom,
    title: title ?? '测试',
    questions: questions,
    revealMode: RevealMode.immediate,
  );
  return id;
}

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('答对但标记不确定：结果页承诺“明天复习”，实际也要明天到期', () async {
    final question = _question('q-uncertain-1');
    final sessionId = await _createSession(database, [question]);
    await database.saveAnswer(
      sessionId: sessionId,
      questionId: question.id,
      selected: {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 1000,
      uncertain: true,
    );
    await database.finalizeSession(
      sessionId: sessionId,
      questionLookup: {question.id: question},
    );

    final items = await database.allReviewItems();
    expect(items, hasLength(1));
    final due = items.single.nextReviewAt;
    expect(due, isNotNull);
    final days = (due! - DateTime.now().millisecondsSinceEpoch) / 86400000;
    // 结果页写的是“已加入明天的复习计划”，必须真的明天到期（约 1 天）。
    expect(days, lessThan(1.05), reason: '实际排到了 $days 天后');
  });

  test('已在错题本里的题：答对并标记不确定，仍应明天复习而不是推后', () async {
    final question = _question('q-uncertain-2');
    // 第一次答错 → 进错题本，stage 0，明天到期。
    final first = await _createSession(database, [question], title: '第一次');
    await database.saveAnswer(
      sessionId: first,
      questionId: question.id,
      selected: {'B'},
      submitted: true,
      isCorrect: false,
      durationMs: 1000,
    );
    await database.finalizeSession(
      sessionId: first,
      questionLookup: {question.id: question},
    );
    expect((await database.allReviewItems()).single.stage, 0);

    // 第二次答对但标记不确定：用户自己也拿不准，明天还得再看一遍。
    final second = await _createSession(database, [question], title: '第二次');
    await database.saveAnswer(
      sessionId: second,
      questionId: question.id,
      selected: {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 1000,
      uncertain: true,
    );
    await database.finalizeSession(
      sessionId: second,
      questionLookup: {question.id: question},
    );

    final item = (await database.allReviewItems()).single;
    expect(item.stage, 0, reason: '不确定的题不应该推进复习阶段');
    expect(item.mastered, isFalse);
    final days =
        (item.nextReviewAt! - DateTime.now().millisecondsSinceEpoch) / 86400000;
    expect(days, lessThan(1.05), reason: '实际排到了 $days 天后');
  });

  test('不标记不确定时，答对仍然正常推进阶段（不要误伤）', () async {
    final question = _question('q-normal-1');
    final first = await _createSession(database, [question], title: '错一次');
    await database.saveAnswer(
      sessionId: first,
      questionId: question.id,
      selected: {'B'},
      submitted: true,
      isCorrect: false,
      durationMs: 1000,
    );
    await database.finalizeSession(
      sessionId: first,
      questionLookup: {question.id: question},
    );

    final second = await _createSession(database, [question], title: '对一次');
    await database.saveAnswer(
      sessionId: second,
      questionId: question.id,
      selected: {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 1000,
    );
    await database.finalizeSession(
      sessionId: second,
      questionLookup: {question.id: question},
    );

    final item = (await database.allReviewItems()).single;
    expect(item.stage, 1);
    final days =
        (item.nextReviewAt! - DateTime.now().millisecondsSinceEpoch) / 86400000;
    expect(days, greaterThan(2.5), reason: '第二阶段是 3 天后');
  });
}
