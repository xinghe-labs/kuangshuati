import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import 'sql_executor.dart';

/// 多题库合并执行器：把每套题库的 content.sqlite ATTACH 到同一个
/// 内存主连接，再为每张业务表建「跨库 UNION ALL」临时视图。
///
/// 为什么用视图而不是改查询：[SqlContentRepository] 里的十几条业务 SQL
/// （抽题、搜题、试卷、图片）全部面向裸表名，视图让它们一行不改就能
/// 工作在多库上——`SELECT * FROM questions` 命中的是合并视图，
/// ORDER BY RANDOM / GROUP BY / json_each 语义不变。
///
/// 注意：SQLite 的 query_only 是连接级 pragma，不能只锁 ATTACH 库，
/// 所以这里不做连接级只读（否则 temp 视图都建不了）；题库只读是
/// 上层约定，业务层只发 SELECT。
///
/// 跨库唯一性约定（视图不做任何 id 改写）：
/// - 官方题库的 question/paper/asset id 全局唯一（建库管线保证）；
/// - 导入题库在入库时把所有 id 加 `<bankId>:` 前缀（见
///   ContentImportService.parseBankJson 的 idPrefix 参数），
///   因此不同库之间 id 不会碰撞，用户库里的引用天然安全。
class MultiBankSqlExecutor implements SqlExecutor {
  MultiBankSqlExecutor._(this._database, this.bankIds);

  /// 主连接：内存库，只承载 temp 视图；所有业务数据在 ATTACH 的库里。
  final Database _database;

  /// 按 ATTACH 顺序排列的 bank id（别名 `bank_<id>`）。
  final List<String> bankIds;

  /// 打开并合并所有题库文件。
  ///
  /// [entries] 为 (bankId, 数据库绝对路径)。任一库打不开或损坏
  /// （quick_check 不过）都抛 [SqliteException]，由上层决定回退策略。
  static Future<MultiBankSqlExecutor> open(
    List<({String bankId, String path})> entries,
  ) async {
    if (entries.isEmpty) {
      throw StateError('MultiBankSqlExecutor.open: no banks');
    }
    final database = sqlite3.openInMemory();
    try {
      for (final entry in entries) {
        final alias = 'bank_${entry.bankId}';
        // ATTACH 支持绑定参数，路径里出现引号等特殊字符也安全。
        database.execute('ATTACH DATABASE ? AS $alias', [entry.path]);
        final integrity = database
            .select('PRAGMA $alias.quick_check')
            .first
            .columnAt(0) as String;
        if (integrity != 'ok') {
          throw StateError(
            'Bank ${entry.bankId} integrity check failed: $integrity',
          );
        }
      }
      for (final table in const ['papers', 'questions', 'assets', 'images']) {
        _createUnionView(database, table, entries);
      }
      return MultiBankSqlExecutor._(
        database,
        entries.map((entry) => entry.bankId).toList(growable: false),
      );
    } on Object {
      database.close();
      rethrow;
    }
  }

  /// 建一张合并视图：`SELECT '<bankId>' AS _bank, * FROM bank_<id>.<table>`
  /// 的 UNION ALL。列名取第一个分支，各库 schema 一致所以安全。
  static void _createUnionView(
    Database database,
    String table,
    List<({String bankId, String path})> entries,
  ) {
    final branches = entries
        .map(
          (entry) =>
              "SELECT '${entry.bankId}' AS _bank, * FROM bank_${entry.bankId}.$table",
        )
        .join(' UNION ALL ');
    database.execute('CREATE TEMP VIEW $table AS $branches');
  }

  /// 指定 bank 的表是否存在（导入/删除后刷新可用性判断用）。
  bool hasTable(String bankId, String table) {
    final rows = _database.select(
      "SELECT 1 FROM bank_$bankId.sqlite_master "
      "WHERE type='table' AND name=? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<ContentRow>> select(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    return _database
        .select(sql, parameters)
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
  }

  @override
  Uint8List? blob(ContentRow row, String column) {
    final value = row[column];
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  @override
  Future<void> close() async => _database.close();
}
