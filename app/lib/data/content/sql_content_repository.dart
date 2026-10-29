import 'dart:convert';
import 'dart:typed_data';

import '../../domain/models.dart';
import 'content_repository.dart';
import 'sql_executor.dart';

/// 题库查询的共用实现。
///
/// 这里只依赖 [SqlExecutor]，不碰 `dart:io` / `dart:ffi`，所以原生端和 Web 端
/// 都能直接复用同一份 SQL 与业务规则（材料组整组抽题、答案隔离、图片按 hash
/// 去重）。两端唯一的差别是「怎么打开数据库」，由子类决定。
class SqlContentRepository implements ContentRepository {
  SqlContentRepository(this._executor, this._manifest);

  final SqlExecutor _executor;
  final Map<String, dynamic> _manifest;

  /// 给平台特有的实现（如 Web 的按需取图）用的底层查询入口。
  /// 只在同一个 data 层内部使用，页面代码不应该直接拿它拼 SQL。
  Future<List<ContentRow>> select(
    String sql, [
    List<Object?> parameters = const [],
  ]) => _executor.select(sql, parameters);

  @override
  Future<ContentStats> stats() async {
    return ContentStats(
      questionCount: await _count('questions') ?? 0,
      paperCount: await _count('papers') ?? 0,
      // Web 端的核心库按设计不包含 `images` 表（图片字节拆成单独文件按需
      // 下载），此时退回清单里声明的张数。原生端有表，走真实计数。
      imageCount:
          await _count('images') ??
          (_manifest['imageCount'] as num?)?.toInt() ??
          0,
      contentVersion: _manifest['contentVersion']?.toString() ?? 'unknown',
    );
  }

  /// 数一张表有多少行；表不存在时返回 null，交给调用方决定怎么退。
  Future<int?> _count(String table) async {
    try {
      final rows = await _executor.select('SELECT COUNT(*) AS n FROM $table');
      return (rows.first['n'] as int?) ?? 0;
    } on Object {
      return null;
    }
  }

  @override
  Future<List<Paper>> recentPapers({int limit = 5}) async {
    final rows = await _executor.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      ORDER BY year DESC, title ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_paperFromRow).toList(growable: false);
  }

  @override
  Future<List<Paper>> searchPapers({String query = '', int? year}) async {
    final normalized = query.trim();
    final rows = await _executor.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      WHERE (? = '' OR title LIKE ? OR region LIKE ?)
        AND (? IS NULL OR year = ?)
      ORDER BY year DESC, title ASC
      ''',
      [normalized, '%$normalized%', '%$normalized%', year, year],
    );
    return rows.map(_paperFromRow).toList(growable: false);
  }

  @override
  Future<Paper?> findPaper(String id) async {
    final rows = await _executor.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );
    return rows.isEmpty ? null : _paperFromRow(rows.first);
  }

  @override
  Future<List<QuestionContent>> questionsForPaper(String paperId) async {
    final rows = await _executor.select(
      '''
      SELECT *
      FROM questions
      WHERE paper_id = ?
      ORDER BY sequence ASC, question_no ASC
      ''',
      [paperId],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  @override
  Future<QuestionContent?> findQuestion(String id) async {
    final rows = await _executor.select(
      'SELECT * FROM questions WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : _questionFromRow(rows.first);
  }

  @override
  Future<List<QuestionContent>> questionsByIds(Iterable<String> ids) async {
    final ordered = ids.toList(growable: false);
    if (ordered.isEmpty) return const [];
    final placeholders = List.filled(ordered.length, '?').join(',');
    final rows = await _executor.select(
      'SELECT * FROM questions WHERE id IN ($placeholders)',
      ordered,
    );
    final byId = {
      for (final row in rows) row['id'] as String: _questionFromRow(row),
    };
    return [for (final id in ordered) ?byId[id]];
  }

  @override
  Future<List<QuestionContent>> randomQuestions(
    int count, {
    String? module,
  }) async {
    if (count <= 0) return const <QuestionContent>[];
    // 开发文档 §9.1 要求“材料组作为抽题最小单位”。但真实题库里有两类例外，
    // 都按单题抽，否则会一次抽出整库或整节：
    //   1) 43 904 道题的上游 groupId 为空，全部塔缩成一个伪组（group_id=''）；
    //   2) 存在 35/50/60 题的超大材料组，装不进 20 题练习。
    // 只有“整组能完整装进本次题量”的材料组才整组抽。
    final units = await _executor.select(
      '''
      SELECT group_id, COUNT(*) AS n
      FROM questions
      WHERE (? IS NULL OR module = ?) AND group_id <> ''
      GROUP BY group_id
      HAVING COUNT(*) <= ?
      ORDER BY RANDOM()
      ''',
      [module, module, count],
    );
    final chosenGroups = <String>[];
    var planned = 0;
    for (final row in units) {
      if (planned >= count) break;
      final n = row['n'] as int;
      // 整组抽题不能把总题量撑过 count：放不下就跳过这组，
      // 由后面的单题补齐。否则随机 20 题会抽成 24 题。
      if (planned + n > count) continue;
      chosenGroups.add(row['group_id'] as String);
      planned += n;
    }
    final picked = <QuestionContent>[];
    if (chosenGroups.isNotEmpty) {
      final placeholders = List.filled(chosenGroups.length, '?').join(', ');
      picked.addAll(
        (await _executor.select(
          '''
              SELECT *
              FROM questions
              WHERE group_id IN ($placeholders) AND (? IS NULL OR module = ?)
              ORDER BY group_id, sequence, question_no
              ''',
          [...chosenGroups, module, module],
        )).map(_questionFromRow),
      );
    }
    if (picked.length < count) {
      // 剩余的由无材料分组的单题和装不进本组练习的大组补足，逐个随机。
      final exclude = chosenGroups.isEmpty
          ? ''
          : 'AND group_id NOT IN (${List.filled(chosenGroups.length, '?').join(', ')})';
      picked.addAll(
        (await _executor.select(
          '''
              SELECT *
              FROM questions
              WHERE (? IS NULL OR module = ?) $exclude
              ORDER BY RANDOM()
              LIMIT ?
              ''',
          [module, module, ...chosenGroups, count - picked.length],
        )).map(_questionFromRow),
      );
    }
    return picked;
  }

  @override
  Future<List<QuestionContent>> sequenceQuestions({int limit = 100}) async {
    final rows = await _executor.select(
      '''
      SELECT *
      FROM questions
      ORDER BY year ASC, paper_id ASC, sequence ASC, question_no ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  @override
  Future<Uint8List?> imageBytes(String assetId) async {
    final image = await imageWithSize(assetId);
    return image?.bytes;
  }

  @override
  Future<ContentImage?> imageWithSize(String assetId) async {
    final rows = await _executor.select(
      '''
      SELECT images.data, images.width, images.height
      FROM assets
      JOIN images ON images.hash = assets.hash
      WHERE assets.asset_id = ? AND assets.available = 1
      LIMIT 1
      ''',
      [assetId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final bytes = _executor.blob(row, 'data');
    if (bytes == null) return null;
    return ContentImage(
      bytes: bytes,
      width: (row['width'] as int?) ?? 0,
      height: (row['height'] as int?) ?? 0,
    );
  }

  /// assetId → 原始高度，命中后永不再查。
  final Map<String, int> _heightCache = {};

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) async {
    final requested = assetIds.toSet();
    final missing = requested
        .where((id) => !_heightCache.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      final placeholders = List.filled(missing.length, '?').join(',');
      for (final row in await _executor.select(
        'SELECT asset_id, height FROM assets '
        'WHERE available = 1 AND asset_id IN ($placeholders)',
        missing,
      )) {
        final height = row['height'];
        if (height is int && height > 0) {
          _heightCache[row['asset_id'] as String] = height;
        }
      }
      for (final id in missing) {
        _heightCache.putIfAbsent(id, () => 0);
      }
    }
    return {
      for (final id in requested)
        if ((_heightCache[id] ?? 0) > 0) id: _heightCache[id]!,
    };
  }

  Paper _paperFromRow(ContentRow row) {
    return Paper(
      id: row['id'] as String,
      title: row['title'] as String,
      year: row['year'] as int,
      region: row['region'] as String,
      paperType: row['paper_type'] as String,
      durationSeconds: row['duration_seconds'] as int,
    );
  }

  QuestionContent _questionFromRow(ContentRow row) {
    final options = (jsonDecode(row['options_json'] as String) as Map)
        .cast<String, String>();
    final correct = (jsonDecode(row['correct_json'] as String) as List)
        .cast<String>()
        .toSet();
    final material = (row['material_markup'] as String?)?.trim();
    return QuestionContent(
      id: row['id'] as String,
      paperId: row['paper_id'] as String,
      questionNo: row['question_no'] as int,
      sequence: row['sequence'] as int,
      module: row['module'] as String,
      stem: row['stem_markup'] as String,
      options: options,
      correctAnswers: correct,
      solution: row['solution_markup'] as String,
      material: material?.isNotEmpty == true ? material : null,
      searchStem: row['stem_text'] as String?,
      groupId: row['group_id'] as String? ?? '',
    );
  }

  @override
  Future<void> close() => _executor.close();
}
