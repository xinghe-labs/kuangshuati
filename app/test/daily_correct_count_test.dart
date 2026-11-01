// 回归：练习模式（答完立即出答案）下，「今日概览·正确」必须真的记上。
//
// 真实调用序列是「先选选项（isCorrect=null）→ 再点提交（isCorrect=true）」。
// 早先当日 correct 只在 selected 从空变有值时累加，那一次 isCorrect 还是
// null，于是每道答对的题都不计正确：首页「已答 10 题 / 正确 0 题」，
// 统计页近 7 天正确率恒为 0%，而模块正确率却正常。
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

  test('练习模式：选中后提交，当日统计必须记 1 题已答 + 1 题正确', () async {
    final questions = [_question('q1'), _question('q2')];
    await database.createSession(
      id: 's1',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      revealMode: RevealMode.immediate,
    );

    // 练习页的真实调用序列：先选选项（未判分），再点提交（判分）。
    await database.saveAnswer(
      sessionId: 's1',
      questionId: 'q1',
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 1000,
      module: '判断推理',
    );
    await database.saveAnswer(
      sessionId: 's1',
      questionId: 'q1',
      selected: {'A'},
      submitted: true,
      isCorrect: true,
      durationMs: 1500,
      module: '判断推理',
    );

    final daily = await database.watchDailyStats().first;
    final today = daily.first;
    expect(today.answeredCount, 1);
    expect(today.correctCount, 1, reason: '答对 1 题，「今日概览·正确」不能是 0');
  });

  test('练习模式：选中后提交答错，当日统计记 0 正确但模块记 1 错', () async {
    final questions = [_question('q1')];
    await database.createSession(
      id: 's2',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: questions,
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: 's2',
      questionId: 'q1',
      selected: {'B'},
      submitted: false,
      isCorrect: null,
      durationMs: 1000,
      module: '判断推理',
    );
    await database.saveAnswer(
      sessionId: 's2',
      questionId: 'q1',
      selected: {'B'},
      submitted: true,
      isCorrect: false,
      durationMs: 1500,
      module: '判断推理',
    );
    final daily = await database.watchDailyStats().first;
    final today = daily.first;
    expect(today.answeredCount, 1);
    expect(today.correctCount, 0);
    final modules = await database.watchModuleStats().first;
    expect(modules.first.answeredCount, 1);
    expect(modules.first.correctCount, 0);
  });
}
