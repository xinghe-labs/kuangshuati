import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/data/database/app_database.dart';
import 'package:kuangshuati/domain/models.dart';

/// 错题本每行都写着「错 N 次 · 空 N 次」，但早先 blankCount 从未被写入，
/// 无论空多少次都恒显「空 0 次」。
void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  final question = const QuestionContent(
    id: 'q-blank',
    paperId: 'p1',
    questionNo: 1,
    sequence: 1,
    module: '言语理解',
    stem: '测试题干',
    options: {'A': '甲', 'B': '乙'},
    correctAnswers: {'A'},
    solution: '解析',
  );

  Future<void> submit({
    required String sessionId,
    required Set<String> selected,
  }) async {
    await database.createSession(
      id: sessionId,
      mode: PracticeMode.custom,
      title: '空题统计',
      questions: [question],
      revealMode: RevealMode.immediate,
    );
    await database.saveAnswer(
      sessionId: sessionId,
      questionId: question.id,
      selected: selected,
      submitted: true,
      isCorrect: selected.isNotEmpty && question.isCorrect(selected),
      durationMs: 1000,
    );
    await database.finalizeSession(
      sessionId: sessionId,
      questionLookup: {question.id: question},
    );
  }

  test('答错进错题本后再交白卷，空次数要 +1 而不是恒为 0', () async {
    await submit(sessionId: 's1', selected: {'B'});
    var items = await database.allReviewItems();
    expect(items.single.wrongCount, 1);
    expect(items.single.blankCount, 0);

    // 第二次做同一题时跳过不答，交卷。
    await submit(sessionId: 's2', selected: const {});
    items = await database.allReviewItems();
    expect(
      items.single.blankCount,
      1,
      reason: '空了一次，错题本上必须显示「空 1 次」',
    );

    await submit(sessionId: 's3', selected: const {});
    items = await database.allReviewItems();
    expect(items.single.blankCount, 2);
    // 空白不该增加错误次数。
    expect(items.single.wrongCount, 1);
  });

  test('从未错过的题交白卷，不会被拉进错题本', () async {
    await submit(sessionId: 's4', selected: const {});
    expect(await database.allReviewItems(), isEmpty);
  });
}
