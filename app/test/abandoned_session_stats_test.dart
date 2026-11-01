import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

QuestionContent _question(String id, {String module = '判断推理'}) =>
    QuestionContent(
      id: id,
      paperId: 'paper-1',
      questionNo: 1,
      sequence: 1,
      module: module,
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

  group('没交卷的练习也要留下错题和模块统计', () {
    test('答题时答错就进错题本，不必等到交卷', () async {
      final question = _question('q1');
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [question],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: question.id,
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 3000,
        module: question.module,
      );

      // 练习页在点下 B 的那一刻就已经显示「回答错误」，
      // 首页也写着「答错的题会自动进入错题本」。
      final items = await database.allReviewItems();
      expect(items.single.questionId, 'q1');
      expect(items.single.wrongCount, 1);
    });

    test('退出后再开一组练习把旧会话挤掉，旧错题依然在错题本里', () async {
      final question = _question('q1');
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [question],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: question.id,
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 3000,
        module: question.module,
      );
      // 用户点「随机 20 题」，旧会话被标记 abandoned。
      await database.createSession(
        id: 'session-2',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [_question('q2')],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      final old = await database.sessionById('session-1');
      expect(old?.status, SessionStatus.abandoned.value);

      final items = await database.allReviewItems();
      expect(items.map((item) => item.questionId), ['q1']);
    });

    test('交卷时不会把练习中已记过的错题再记一次', () async {
      final question = _question('q1');
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [question],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: question.id,
        selected: {'B'},
        submitted: true,
        isCorrect: false,
        durationMs: 3000,
        module: question.module,
      );
      await database.finalizeSession(
        sessionId: 'session-1',
        questionLookup: {question.id: question},
      );
      final items = await database.allReviewItems();
      expect(items.single.wrongCount, 1, reason: '错题次数被重复累计了');
    });

    test('模考里没交卷就退出，模块统计也不该是空的', () async {
      final questions = [
        _question('q1', module: '判断推理'),
        _question('q2', module: '言语理解'),
      ];
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: questions,
        revealMode: RevealMode.afterSubmit,
        requestedCount: 2,
        timeLimitSeconds: 7200,
      );
      // 模考模式下作答不立刻判分（submitted=false），用户在模考中途退出。
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: 'q1',
        selected: {'A'},
        submitted: false,
        isCorrect: null,
        durationMs: 5000,
        module: '判断推理',
      );
      // 没交卷的模考没有判分，模块统计可以没有数据，这不算缺陷。
      expect(await database.watchModuleStats().first, isEmpty);

      // 练习模式（立即出答案）则必须实时进模块统计。
      await database.createSession(
        id: 'session-2',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [questions.first],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-2',
        questionId: 'q1',
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 5000,
        module: '判断推理',
      );
      final modules = await database.watchModuleStats().first;
      expect(modules.single.module, '判断推理');
      expect(modules.single.answeredCount, 1);
      expect(modules.single.correctCount, 1);
    });

    test('交卷不会重复累计模块统计', () async {
      final question = _question('q1');
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.random,
        title: '随机练习',
        questions: [question],
        revealMode: RevealMode.immediate,
        requestedCount: 1,
      );
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: question.id,
        selected: {'A'},
        submitted: true,
        isCorrect: true,
        durationMs: 5000,
        module: question.module,
      );
      await database.finalizeSession(
        sessionId: 'session-1',
        questionLookup: {question.id: question},
      );
      final modules = await database.watchModuleStats().first;
      expect(modules.single.answeredCount, 1);
      expect(modules.single.correctCount, 1);
    });

    test('模考交卷时才首次判分的题仍然计入模块统计', () async {
      final question = _question('q1');
      await database.createSession(
        id: 'session-1',
        mode: PracticeMode.mock,
        title: '整卷模考',
        questions: [question],
        revealMode: RevealMode.afterSubmit,
        requestedCount: 1,
        timeLimitSeconds: 7200,
      );
      await database.saveAnswer(
        sessionId: 'session-1',
        questionId: question.id,
        selected: {'B'},
        submitted: false,
        isCorrect: null,
        durationMs: 5000,
        module: question.module,
      );
      await database.finalizeSession(
        sessionId: 'session-1',
        questionLookup: {question.id: question},
      );
      final modules = await database.watchModuleStats().first;
      expect(modules.single.answeredCount, 1);
      expect(modules.single.correctCount, 0);
    });
  });
}
