enum PracticeMode {
  sequence,
  random,
  paper,
  wrong,
  custom,
  mock;

  String get label => switch (this) {
    PracticeMode.sequence => '顺序练习',
    PracticeMode.random => '随机练习',
    PracticeMode.paper => '试卷练习',
    PracticeMode.wrong => '错题复习',
    PracticeMode.custom => '自定义组卷',
    PracticeMode.mock => '整卷模考',
  };
}

enum RevealMode {
  immediate,
  afterSubmit;

  String get value => name;
}

enum SessionStatus {
  active,
  submitted,
  abandoned;

  String get value => name;
}

class Paper {
  const Paper({
    required this.id,
    required this.title,
    required this.year,
    required this.region,
    required this.paperType,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final int year;
  final String region;
  final String paperType;
  final int durationSeconds;
}

class QuestionContent {
  const QuestionContent({
    required this.id,
    required this.paperId,
    required this.questionNo,
    required this.sequence,
    required this.module,
    required this.stem,
    required this.options,
    required this.correctAnswers,
    required this.solution,
    this.material,
    this.searchStem,
    this.groupId = '',
  });

  final String id;
  final String paperId;

  /// 原卷里的题号。一份卷子分多个模块时，每个模块的题号都从 1 重新数，
  /// 所以它不是卷内唯一位置，只用于回溯原卷。
  final int questionNo;

  /// 卷内顺序号（1..N，按原文档顺序），唯一且可用于展示“第 N 题”。
  final int sequence;

  final String module;
  final String stem;
  final Map<String, String> options;
  final Set<String> correctAnswers;
  final String solution;
  final String? material;
  final String? searchStem;

  /// 材料组 ID：同一段材料下的小题共享它。抽题时整组取，不能拆散。
  /// 演示数据集没有分组信息时为空串。
  final String groupId;

  String get plainStem {
    final indexed = searchStem?.trim();
    if (indexed != null && indexed.isNotEmpty) return indexed;
    return stem.replaceAll(RegExp('\ue000[^\ue001]+\ue001'), ' [图片] ');
  }

  bool isCorrect(Iterable<String> selected) {
    final normalized = selected.toSet();
    return normalized.length == correctAnswers.length &&
        normalized.containsAll(correctAnswers);
  }
}

class AnswerOutcome {
  const AnswerOutcome({
    required this.isCorrect,
    required this.correctAnswers,
    required this.solution,
  });

  final bool isCorrect;
  final Set<String> correctAnswers;
  final String solution;
}

class SessionQuestion {
  const SessionQuestion({required this.position, required this.question});

  final int position;
  final QuestionContent question;
}

class SessionAnswer {
  const SessionAnswer({
    required this.questionId,
    required this.selected,
    required this.submitted,
    required this.isCorrect,
    required this.durationMs,
    this.uncertain = false,
  });

  final String questionId;
  final Set<String> selected;
  final bool submitted;
  final bool? isCorrect;
  final int durationMs;
  final bool uncertain;
}

/// 练习天数汇总（开发文档 §11.3）：总练习天数与连续练习天数。
class PracticeStreak {
  const PracticeStreak({
    required this.currentDays,
    required this.totalDays,
    this.lastDay,
  });

  static const empty = PracticeStreak(currentDays: 0, totalDays: 0);

  /// 连续练习天数。
  final int currentDays;

  /// 累计练习天数（按自然日去重）。
  final int totalDays;

  /// 最近一次计入的本地自然日，格式 `YYYY-MM-DD`。
  final String? lastDay;
}

/// 一次练习的作答概况（历史记录列表 / 回看成绩用）。
class SessionSummary {
  const SessionSummary({
    required this.totalCount,
    required this.answeredCount,
    required this.correctCount,
    this.gradedCount,
  });

  static const empty = SessionSummary(
    totalCount: 0,
    answeredCount: 0,
    correctCount: 0,
  );

  final int totalCount;
  final int answeredCount;
  final int correctCount;

  /// 真正判过分的题数。
  ///
  /// 没交卷就被结束的练习里，答案只是“选了选项”（`isCorrect` 为 null），
  /// 不能算作答对也不能算答错。早先列表用 [correctCount] / [answeredCount]
  /// 直接算正确率，一场做了 2 题、没交卷的模考会显示「正确率 0%」，
  /// 实际上用户当时根本还没看到对错。
  final int? gradedCount;

  int get _graded => gradedCount ?? answeredCount;

  int get scorePercent =>
      _graded == 0 ? 0 : (correctCount * 100 / _graded).round();
}
