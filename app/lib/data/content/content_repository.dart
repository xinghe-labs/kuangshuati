import 'dart:async';
import 'dart:typed_data';

import '../../domain/models.dart';

/// 一张题图：字节 + 原始尺寸，供行内混排按高度分流渲染。
class ContentImage {
  const ContentImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

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

  /// 取图并带原始尺寸；行内公式图需要按高度决定行内/块级渲染。
  FutureOr<ContentImage?> imageWithSize(String assetId) => null;

  /// 取这批图的原始高度（构建阶段决定行内/块级）。
  /// 只查当前 markup 里出现的少量 assetId，走主键索引，开销可忽略。
  /// 声明为异步是因为 Web 端（drift WASM）只有异步查询接口。
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async =>
      const {};

  Future<void> close();
}
