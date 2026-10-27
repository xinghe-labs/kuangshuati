import 'dart:async';
import 'dart:typed_data';

import '../../domain/models.dart';

class ContentStats {
  const ContentStats({
    required this.questionCount,
    required this.paperCount,
    required this.imageCount,
    required this.contentVersion,
  });

  final int questionCount;
  final int paperCount;
  final int imageCount;
  final String contentVersion;
}

abstract class ContentRepository {
  FutureOr<ContentStats> stats();

  FutureOr<List<Paper>> recentPapers({int limit = 5});

  FutureOr<List<Paper>> searchPapers({String query = '', int? year});

  FutureOr<Paper?> findPaper(String id);

  FutureOr<List<QuestionContent>> questionsForPaper(String paperId);

  FutureOr<QuestionContent?> findQuestion(String id);

  FutureOr<List<QuestionContent>> questionsByIds(Iterable<String> ids);

  FutureOr<List<QuestionContent>> randomQuestions(int count, {String? module});

  FutureOr<List<QuestionContent>> sequenceQuestions({int limit = 100});

  FutureOr<Uint8List?> imageBytes(String assetId);

  void close();
}
