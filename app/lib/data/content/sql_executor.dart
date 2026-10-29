import 'dart:typed_data';

/// 一行查询结果：列名 → 值。
///
/// 原生端由 `package:sqlite3` 的 `Row` 转换而来，Web 端由 drift 的
/// `QueryRow.data` 转换而来。两边都归一到这个形状，题库查询逻辑就能完全
/// 共用一份，不会出现"原生查对了、Web 查错了"的语义漂移。
typedef ContentRow = Map<String, Object?>;

/// 只读 SQL 执行器。
///
/// 题库数据是只读的：原生端以 `mode=readOnly` 打开 content.sqlite，
/// Web 端把打包好的库文件塞进 drift 的浏览器存储后同样只做 SELECT。
///
/// 签名是异步的：原生 `package:sqlite3` 是同步的（用 `Future.value` 包一层，
/// 没有额外开销），而 Web 端 drift 的 WASM 执行器只有异步 API。统一成异步，
/// 上层的 [SqlContentRepository] 才能两端共用。
abstract class SqlExecutor {
  /// 执行 SELECT，返回全部行。
  Future<List<ContentRow>> select(
    String sql, [
    List<Object?> parameters = const [],
  ]);

  /// 取单个 blob 列（图片数据）。Web 端 drift 返回 `Uint8List`，
  /// 原生端可能给 `List<int>`，在这里统一收口。
  Uint8List? blob(ContentRow row, String column);

  Future<void> close();
}
