// 探针：模考（交卷后统一判分）里答了题但没交卷，
// 首页说「已答 N 题」，统计页「今日已答」「模块正确率」却全是 0。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

QuestionContent _question(int index) => QuestionContent(
  id: 'q-$index',
  paperId: 'paper-1',
  questionNo: index,
  sequence: index,
  module: '判断推理',
  stem: '题干 $index',
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

  test('模考答了题但没交卷：首页已答 3 题，统计页今日已答却是 0', () async {
    final questions = [for (var i = 1; i <= 5; i++) _question(i)];
    await database.createSession(
      id: 'mock-1',
      mode: PracticeMode.mock,
      title: '整卷模考',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
      requestedCount: 5,
      timeLimitSeconds: 7200,
    );
    // 模考模式下练习页选完选项就是这样落库的：submitted=false。
    for (var i = 1; i <= 3; i++) {
      await database.saveAnswer(
        sessionId: 'mock-1',
        questionId: 'q-$i',
        selected: {'A'},
        submitted: false,
        isCorrect: null,
        durationMs: 5000,
        module: '判断推理',
      );
    }

    final submittedCount = await database.submittedCountFor('mock-1');
    final daily = (await database.watchDailyStats().first).firstOrNull;
    final modules = await database.watchModuleStats().first;
    // ignore: avoid_print
    print(
      'PROBE submittedCount=$submittedCount '
      'todayAnswered=${daily?.answeredCount ?? 0} '
      'modules=${modules.map((m) => "${m.module}:${m.answeredCount}/${m.correctCount}").join(",")}',
    );
    expect(submittedCount, 3, reason: '首页「已答」按选过选项统计');
    // 这两个数字和上面的 3 对不上，就是用户看到的「统计说今天 0 题」。
    expect(daily?.answeredCount ?? 0, 3);
    // 模考中途没交卷 → 还没判分，模块正确率不能凭空按 0 分记，
    // 否则 3 道可能全对的题会把「判断推理」的正确率拉到 0%。
    expect(modules, isEmpty);
  });
}
