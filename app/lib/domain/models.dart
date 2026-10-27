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
    required this.module,
    required this.stem,
    required this.options,
    required this.correctAnswers,
    required this.solution,
    this.material,
    this.searchStem,
  });

  final String id;
  final String paperId;
  final int questionNo;
  final String module;
  final String stem;
  final Map<String, String> options;
  final Set<String> correctAnswers;
  final String solution;
  final String? material;
  final String? searchStem;

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
