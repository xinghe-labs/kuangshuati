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
      -- 导入时未组卷的散题自动归入「未组卷题目」虚拟卷，year 为 0；
      -- 置顶展示，避免被真实年份的真题卷淹在列表底部。
      ORDER BY (title = '未组卷题目') DESC, year DESC, title ASC
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
  Future<List<QuestionContent>> searchQuestions(
    String query, {
    int limit = 200,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const <QuestionContent>[];
    // 题干、材料、选项都搜：用户往往只记得选项里的一个词（如“基层治理”），
    // 不一定记得题干怎么写的。
    // 用 instr 而不是 LIKE '%...%'：用户输入的 % 和 _ 在 LIKE 里是通配符，
    // 搜“20%”这种题干会变成模糊匹配、结果全乱。
    //
    // 两侧都转小写：题干里有大量英文缩写（GDP 93 题、APP 32 题、AI 132 题），
    // 而 instr 是大小写敏感的。界面会把输入先 toLowerCase，于是用户按题干
    // 里看到的“GDP”去搜，实际查的是“gdp”，命中 0 条，误以为题库里没有。
    final needle = normalized.toLowerCase();
    // 只按年份倒序：实测多列 ORDER BY（year DESC, paper_id, sequence）
    // 会让 SQLite 必须把命中的全部行排完才能取前 200 条，搜“的”要 1.7s；
    // 单列 year DESC 可以直接走 questions_year 索引倒序扫，只要 5ms。
    final rows = await _executor.select(
      '''
      SELECT *
      FROM questions
      WHERE instr(lower(stem_text), ?) > 0
         OR instr(lower(COALESCE(material_markup, '')), ?) > 0
         OR instr(lower(options_json), ?) > 0
      ORDER BY year DESC
      LIMIT ?
      ''',
      [needle, needle, needle, limit],
    );
    return rows.map(_questionFromRow).toList(growable: false);
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
  Future<Map<String, int>> moduleCounts() async {
    final rows = await _executor.select(
      'SELECT module, COUNT(*) AS n FROM questions GROUP BY module',
    );
    return {
      for (final row in rows)
        (row['module'] as String?) ?? '': row['n'] as int,
    };
  }

  @override
  Future<List<QuestionContent>> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  }) async {
    // 已做过的题来自 App 自己的数据库（答题历史），不在题库文件里，
    // 所以只能把 id 传进来。
    //
    // 不能直接拼 `id NOT IN (?,?,?...)`：SQLite 一条语句最多 32766 个绑定
    // 变量（实测传 40000 个 id 报 “too many SQL variables”），而顺序练习要把
    // “全部做过的题”都排掉，老用户很容易超过这个数。
    // 也不能分批查询：NOT IN 只对当前批生效，第二批会把第一批排除的题又
    // 取回来（实测会重复返回已做过的题）。
    //
    // 改用单个参数传 JSON，交给 SQLite 的 json_each 展开（题库 SQLite 编译时
    // 已带 JSON1），一个绑定变量就能排除任意多个 id。
    final excluded = excludeIds.toSet();
    if (excluded.isEmpty) {
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
    final rows = await _executor.select(
      '''
      SELECT *
      FROM questions
      WHERE id NOT IN (SELECT value FROM json_each(?))
      ORDER BY year ASC, paper_id ASC, sequence ASC, question_no ASC
      LIMIT ?
      ''',
      [jsonEncode(excluded.toList(growable: false)), limit],
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
