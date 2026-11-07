// 限时训练：单题限时档位存在会话上，杀进程后继续练习也能恢复。
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
  test('createSession 写入 questionLimitSeconds 并能读回', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.createSession(
      id: 's1',
      mode: PracticeMode.random,
      title: '限时训练',
      questions: [_question('q1')],
      revealMode: RevealMode.immediate,
      questionLimitSeconds: 75,
    );
    final row = await (database.select(database.practiceSessions)
          ..where((r) => r.id.equals('s1')))
        .getSingle();
    expect(row.questionLimitSeconds, 75);
  });

  test('普通会话不传档位时为 null（跟随全局设置）', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.createSession(
      id: 's2',
      mode: PracticeMode.random,
      title: '随机练习',
      questions: [_question('q1')],
      revealMode: RevealMode.immediate,
    );
    final row = await (database.select(database.practiceSessions)
          ..where((r) => r.id.equals('s2')))
        .getSingle();
    expect(row.questionLimitSeconds, isNull);
  });
}
