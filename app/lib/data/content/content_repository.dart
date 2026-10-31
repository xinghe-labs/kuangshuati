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

  /// 顺序练习：按年份/试卷/题号返回题目。
  ///
  /// [excludeIds] 用于跳过用户已经做过的题。
  /// 为什么需要：早先固定返回题库最前面的 100 题，用户每次点“顺序练习”
  /// 拿到的都是同一批（题库共 58890 题，而顺序练习永远只覆盖前 100 题），
  /// 练完之后要么重复刷同一批，要么以为题量就这么点。
  FutureOr<List<QuestionContent>> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  });

  /// 按题干/材料/选项文本搜题。
  ///
  /// 为什么需要：题库有 58890 道题，而首页和题库页的搜索框只能搜
  /// 试卷标题和地区。用户想找“那道做错过的题”时，按题干搜得到 0 条结果，
  /// 只能一份份试卷点进去翻——实际使用中基本等于找不到。
  ///
  /// [limit] 用于限制返回量，避免一个很短的查询词（如“下列”）把几万道题
  /// 全部拉进列表。
  FutureOr<List<QuestionContent>> searchQuestions(
    String query, {
    int limit = 200,
  });

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
