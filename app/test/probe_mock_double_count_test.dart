// 临时探针：模考（交卷后统一判分）模式下的当日统计是否重复计数。
//
// 真实路径：模考里每选一个选项就 saveAnswer 一次（submitted=false，
// isCorrect=null），此时 firstAnswer=true → 当日「已答」+1；
// 交卷时 finalizeSession 又对「选过选项但没提交」的题 freshAnswered++，
// 当日「已答」再 +1。同一道题被记了两次。
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

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('模考答 2 题后交卷：当日已答必须是 2，不是 4', () async {
    final questions = [_question('q1'), _question('q2'), _question('q3')];
    await database.createSession(
      id: 'mock',
      mode: PracticeMode.mock,
      title: '整卷模考',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
    );
    // 模考里选选项：只落库，不判分。
    for (final id in ['q1', 'q2']) {
      await database.saveAnswer(
        sessionId: 'mock',
        questionId: id,
        selected: {'A'},
        submitted: false,
        isCorrect: null,
        durationMs: 1000,
        module: '判断推理',
      );
    }
    await database.finalizeSession(
      sessionId: 'mock',
      questionLookup: {for (final q in questions) q.id: q},
    );
    final daily = await database.watchDailyStats().first;
    final today = daily.first;
    // ignore: avoid_print
    print('DAILY answered=${today.answeredCount} correct=${today.correctCount}');
    expect(today.answeredCount, 2, reason: '答了 2 题不能显示成 4 题');
    expect(today.correctCount, 2);
  });

  test('模考中途退出再交卷：已答只算一次', () async {
    final questions = [_question('q1'), _question('q2')];
    await database.createSession(
      id: 'mock2',
      mode: PracticeMode.mock,
      title: '整卷模考',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
    );
    await database.saveAnswer(
      sessionId: 'mock2',
      questionId: 'q1',
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 1000,
      module: '判断推理',
    );
    // 翻题/退出前保存会再落一次库。
    await database.saveAnswer(
      sessionId: 'mock2',
      questionId: 'q1',
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 1200,
      module: '判断推理',
    );
    await database.finalizeSession(
      sessionId: 'mock2',
      questionLookup: {for (final q in questions) q.id: q},
    );
    final daily = await database.watchDailyStats().first;
    expect(daily.first.answeredCount, 1);
    expect(daily.first.correctCount, 1);
  });
}
