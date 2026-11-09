import 'dart:convert';
import 'dart:math' as math;
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
  final math.Random _random = math.Random();

  /// 抽题索引缓存（全库一份，按模块在内存里筛）。
  ///
  /// 题库文件只读，同一份库的题目构成不会变；而随机抽题原先每次都让
  /// SQLite 全表扫一遍再排序（实测「随机 20 题」540 ms，随机模考 6 个
  /// 模块 4.8 s）。装载一次后，每次抽题只按主键取行。
  ///
  /// 存 Future 而不是结果：随机模考会连续调用，避免并发时重复装载。
  Future<_QuestionIndex>? _index;

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
    final index = await _questionIndex();
    // 随机完全在 Dart 里做，不交给 SQL 的 `ORDER BY RANDOM()`：后者会让
    // SQLite 为整库建临时排序表，而随机抽题并不需要 SQL 排任何东西。
    final groupIds = [
      for (final entry in index.byGroup.entries)
        if ((module == null || index.groupModule[entry.key] == module) &&
            entry.value.length <= count)
          entry.key,
    ]..shuffle(_random);
    final chosen = <String>{};
    var planned = 0;
    for (final groupId in groupIds) {
      if (planned >= count) break;
      final size = index.byGroup[groupId]!.length;
      // 整组抽题不能把总题量撑过 count：放不下就跳过这组，
      // 由后面的单题补齐。否则随机 20 题会抽成 24 题。
      if (planned + size > count) continue;
      chosen.add(groupId);
      planned += size;
    }
    final ids = <String>[
      for (final groupId in chosen) ...index.byGroup[groupId]!,
    ];
    if (ids.length < count) {
      // 剩余的由无材料分组的单题和装不进本组练习的大组补足。
      final used = ids.toSet();
      final pool = module == null
          ? index.allIds
          : (index.idsByModule[module] ?? const <String>[]);
      ids.addAll(
        _sample([
          for (final id in pool)
            if (!used.contains(id)) id,
        ], count - ids.length),
      );
    }
    return questionsByIds(ids);
  }

  /// 从 [pool] 里随机挑 [k] 个。
  ///
  /// 只做 k 次取下标，不洗整个池：全库 5.9 万个 id 洗一遍每次都要几毫秒，
  /// 而一次练习只取 20 个。
  List<String> _sample(List<String> pool, int k) {
    if (k <= 0) return const <String>[];
    // 取得多时直接洗牌更快（否则要重试到抽满）。
    if (k * 2 >= pool.length) {
      return (List<String>.of(pool)..shuffle(_random)).take(k).toList();
    }
    final taken = <int>{};
    final picked = <String>[];
    while (picked.length < k) {
      final i = _random.nextInt(pool.length);
      if (taken.add(i)) picked.add(pool[i]);
    }
    return picked;
  }

  /// 装载抽题索引（题目 id 清单 + 材料组），整个仓储生命周期只装载一次。
  Future<_QuestionIndex> _questionIndex() =>
      _index ??= _loadIndex();

  Future<_QuestionIndex> _loadIndex() async {
    final rows = await _executor.select(
      '''
      SELECT id, module, group_id, sequence, question_no
      FROM questions
      ''',
    );
    final idsByModule = <String, List<String>>{};
    final grouped = <String, List<(int, int, String)>>{};
    final groupModule = <String, String>{};
    for (final row in rows) {
      final id = row['id'] as String;
      final module = (row['module'] as String?) ?? '';
      (idsByModule[module] ??= []).add(id);
      final groupId = (row['group_id'] as String?) ?? '';
      if (groupId.isEmpty) continue;
      groupModule[groupId] = module;
      (grouped[groupId] ??= []).add((
        (row['sequence'] as int?) ?? 0,
        (row['question_no'] as int?) ?? 0,
        id,
      ));
    }
    // 组内按 sequence / question_no 排好：材料题（1）（2）（3）必须按原序
    // 呈现，否则会出现先问（3）再问（1）。
    final byGroup = <String, List<String>>{
      for (final entry in grouped.entries)
        entry.key:
            ([...entry.value]..sort((a, b) {
                  final bySequence = a.$1.compareTo(b.$1);
                  return bySequence != 0
                      ? bySequence
                      : a.$2.compareTo(b.$2);
                }))
                .map((item) => item.$3)
                .toList(growable: false),
    };
    return _QuestionIndex(
      idsByModule: idsByModule,
      byGroup: byGroup,
      groupModule: groupModule,
    );
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

/// 抽题索引：题目 id 清单与材料组，按模块切好。
///
/// 建它的目的是把随机性从 SQL 里拿出来：`ORDER BY RANDOM()` 必须让 SQLite
/// 扫全表再排序，而这份索引装载一次后，抽题只剩「按主键取 20 行」。
class _QuestionIndex {
  _QuestionIndex({
    required this.idsByModule,
    required this.byGroup,
    required this.groupModule,
  });

  /// module -> 该模块全部题目 id（顺序无意义，抽题时随机挑）。
  final Map<String, List<String>> idsByModule;

  /// group_id -> 组内题目 id（已按 sequence / question_no 排好）。
  /// 空 group_id 的题目不在这里（它们按单题抽）。
  final Map<String, List<String>> byGroup;

  /// group_id -> 所属模块，用于按模块筛材料组。
  final Map<String, String> groupModule;

  List<String>? _allIds;

  /// 全库题目 id（跨模块抽题时用），首次访问时拼好。
  List<String> get allIds => _allIds ??= [
    for (final ids in idsByModule.values) ...ids,
  ];
}
