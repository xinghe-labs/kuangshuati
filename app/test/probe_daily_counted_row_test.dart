// 临时探针：检查 dailyCounted 是否真的写进数据库行。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

QuestionContent _question(String id) => QuestionContent(
  id: id,
  paperId: 'p',
  questionNo: 1,
  sequence: 1,
  module: '判断推理',
  stem: 's $id',
  options: const {'A': '甲', 'B': '乙'},
  correctAnswers: const {'A'},
  solution: '',
  searchStem: null,
  groupId: '',
);

void main() {
  test('dailyCounted 落库', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final questions = [_question('q1')];
    await database.createSession(
      id: 's',
      mode: PracticeMode.mock,
      title: 'm',
      questions: questions,
      revealMode: RevealMode.afterSubmit,
    );
    await database.saveAnswer(
      sessionId: 's',
      questionId: 'q1',
      selected: {'A'},
      submitted: false,
      isCorrect: null,
      durationMs: 100,
      module: '判断推理',
    );
    final rows = await database.answersForSession('s');
    // ignore: avoid_print
    print('ROW dailyCounted=${rows.first.dailyCounted} '
        'moduleCounted=${rows.first.moduleCounted}');
    expect(rows.first.dailyCounted, isTrue);
  });
}
