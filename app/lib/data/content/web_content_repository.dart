import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:sqlite3/wasm.dart';

import '../../domain/models.dart';
import 'content_repository.dart';
import 'sql_content_repository.dart';
import 'sql_executor.dart';
import 'web_blob_store.dart';

/// Web 端题库实现。
///
/// 浏览器里没有 `dart:ffi`，所以不能用 `package:sqlite3` 的原生绑定。这里改用
/// sqlite3 的 WebAssembly 版本：把构建期打包好的 core 数据库文件（只含题面，
/// 不含解析和图片）写进浏览器的 IndexedDB 虚拟文件系统，之后用同一份 SQL
/// 查询。这样抽题规则和原生端完全共用 [SqlContentRepository]，不存在
/// "网页抽出来的题和手机上不一样"的风险。
///
/// 为什么不用 `WasmDatabase.open`：它把「首次灌库」交给
/// `initializeDatabase` 回调，而这个回调只在 worker 主动索要初始数据时才被
/// 调用。实测（Edge headless、OPFS/IndexedDB 全空）`open` 会在 200ms 内返回
/// `opfsLocks`，但回调一次都不触发、库里也没有表，随后读表抛
/// `LateInitializationError: Field '' has not been initialized`。与其依赖这条
/// 不可观测的通道，不如自己拿 sqlite3 wasm + [IndexedDbFileSystem] 把字节写进
/// `/database` 再打开：每一步都同步可见，失败也能拿到真实错误。
class WebContentRepository implements ContentRepository {
  WebContentRepository._(this._inner, this._images);

  final SqlContentRepository _inner;
  final _WebImageStore? _images;

  /// 浏览器里存题库用的数据库名（IndexedDB 里的库名）。
  ///
  /// 字节存在 [ContentBlobStore] 里（库名 `kuangshuati_content_v2`）。旧版本
  /// 用 `IndexedDbFileSystem` 存的 `kuangshuati_content` 已经读不出来，留者
  /// 无用，下次安装时顺手删掉。
  static const String databaseName = 'kuangshuati_content';

  /// 虚拟文件系统里题库文件的位置。sqlite3 的 wasm 版默认把主库叫
  /// `/database`，这里保持一致。
  static const String _databasePath = '/database';

  /// 打开（或首次初始化）浏览器内的题库数据库。
  ///
  /// [databaseBytesLoader] 只在浏览器里还没有题库时被调用一次，用来提供
  /// 打包好的数据库字节；返回 null 表示「建一个空库」。已有副本时不会被调用。
  static Future<WebContentRepository> open({
    required Uri sqlite3Wasm,
    required Future<Uint8List?> Function() databaseBytesLoader,
    required Map<String, dynamic> manifest,
    Uri? imageBaseUri,
  }) async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(sqlite3Wasm);

    // 用内存 VFS 承接字节。库自带的 [IndexedDbFileSystem] 跨页面重开时
    // 读不出数据（原因见 web_blob_store.dart 顶部注释），所以持久化交给
    // [ContentBlobStore]，sqlite 只面对一个同步的内存文件。
    final store = await ContentBlobStore.open();
    Uint8List? bytes = await store.readAll();
    var effectiveManifest = manifest;
    if (bytes != null && bytes.isNotEmpty) {
      debugPrint('Web 题库命中浏览器缓存：${bytes.length} 字节');
      // 命中缓存时调用方往往只传空清单（它不知道当初装的是哪个版本），
      // 这时用安装时存下的那份，否则版本号会退化成 unknown。
      if (manifest.isEmpty) {
        final storedInfo = await store.readContentInfo();
        if (storedInfo != null) {
          try {
            final decoded = jsonDecode(storedInfo);
            if (decoded is Map<String, dynamic>) {
              effectiveManifest = decoded;
            }
          } on Object catch (decodeError) {
            debugPrint('Web 题库清单解析失败：$decodeError');
          }
        }
      }
    } else {
      bytes = await databaseBytesLoader();
      if (bytes != null && bytes.isNotEmpty) {
        // 先把字节落盘再打开。浏览器崩溃或用户中途关页面时，至少不会留下
        // 一个“有文件但长度是 0”的坏缓存。
        try {
          await store.writeAll(bytes);
          // 清单跟字节一起存。下载路径传进来的就是最新的远端清单。
          if (manifest.isNotEmpty) {
            await store.writeContentInfo(jsonEncode(manifest));
          }
          debugPrint('Web 题库已缓存到浏览器：${bytes.length} 字节');
        } on Object catch (writeError, stack) {
          // 写盘失败不该挡住本次使用：内存里已经拿到字节，照样能刷题，
          // 只是下次打开还要重新下载。
          debugPrint('Web 题库写入浏览器存储失败：$writeError');
          debugPrint('$stack');
        }
      }
    }

    final vfs = InMemoryFileSystem();
    sqlite3.registerVirtualFileSystem(vfs, makeDefault: true);
    if (bytes != null && bytes.isNotEmpty) {
      final opened = vfs.xOpen(
        Sqlite3Filename(_databasePath),
        SqlFlag.SQLITE_OPEN_CREATE,
      );
      opened.file
        ..xWrite(bytes, 0)
        ..xClose();
    }

    final database = sqlite3.open(_databasePath);
    // 题库只读：打开后立刻进入 query_only，避免任何误写把缓存改坏。
    database.execute('PRAGMA query_only = ON');
    final inner = SqlContentRepository(
      _WasmSqlExecutor(database, vfs, store),
      effectiveManifest,
    );
    return WebContentRepository._(
      inner,
      imageBaseUri == null ? null : _WebImageStore(inner, imageBaseUri),
    );
  }

  /// 浏览器里是否已经装了题库。
  ///
  /// 只看 [ContentBlobStore] 里有没有字节，不打开 sqlite。
  static Future<bool> hasCachedDatabase({required Uri sqlite3Wasm}) async {
    final store = await ContentBlobStore.open();
    try {
      final bytes = await store.readAll();
      final exists = bytes != null && bytes.isNotEmpty;
      return exists;
    } finally {
      store.close();
    }
  }

  @override
  Future<ContentStats> stats() => _inner.stats();

  @override
  Future<List<Paper>> recentPapers({int limit = 5}) =>
      _inner.recentPapers(limit: limit);

  @override
  Future<List<Paper>> searchPapers({String query = '', int? year}) =>
      _inner.searchPapers(query: query, year: year);

  @override
  Future<Paper?> findPaper(String id) => _inner.findPaper(id);

  @override
  Future<List<QuestionContent>> questionsForPaper(String paperId) =>
      _inner.questionsForPaper(paperId);

  @override
  Future<QuestionContent?> findQuestion(String id) => _inner.findQuestion(id);

  @override
  Future<List<QuestionContent>> questionsByIds(Iterable<String> ids) =>
      _inner.questionsByIds(ids);

  @override
  Future<List<QuestionContent>> randomQuestions(int count, {String? module}) =>
      _inner.randomQuestions(count, module: module);

  @override
  Future<Map<String, int>> moduleCounts() => _inner.moduleCounts();

  @override
  Future<List<QuestionContent>> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  }) => _inner.sequenceQuestions(limit: limit, excludeIds: excludeIds);

  @override
  Future<List<QuestionContent>> searchQuestions(
    String query, {
    int limit = 200,
  }) => _inner.searchQuestions(query, limit: limit);

  @override
  Future<Uint8List?> imageBytes(String assetId) {
    final images = _images;
    if (images == null) return _inner.imageBytes(assetId);
    return images.bytes(assetId);
  }

  @override
  Future<ContentImage?> imageWithSize(String assetId) {
    final images = _images;
    if (images == null) return _inner.imageWithSize(assetId);
    return images.withSize(assetId);
  }

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) =>
      _inner.imageHeights(assetIds);

  @override
  Future<void> close() async {
    await _inner.close();
  }
}

/// 按需取图。
///
/// 图片在 Web 端不放进核心库（否则首屏要多下 97 MiB），而是构建时拆成
/// `<hash>.bin` 一个个文件。这里先用 assetId 查 hash 和尺寸（本地库，很快），
/// 再去拉文件；浏览器 HTTP 缓存负责第二次之后的命中，所以同一张图只会
/// 真正下载一次。
class _WebImageStore {
  _WebImageStore(this._inner, this._baseUri);

  final SqlContentRepository _inner;
  final Uri _baseUri;
  final http.Client _client = http.Client();

  /// 内存里留最近用过的若干张，避免上下滑动时反复读网络层。
  final Map<String, Uint8List> _cache = {};
  static const int _cacheLimit = 24;

  Future<ContentImage?> withSize(String assetId) async {
    final descriptor = await _descriptor(assetId);
    if (descriptor == null) return null;
    final payload = await bytes(assetId);
    if (payload == null) return null;
    return ContentImage(
      bytes: payload,
      width: descriptor.width,
      height: descriptor.height,
    );
  }

  Future<Uint8List?> bytes(String assetId) async {
    final cached = _cache[assetId];
    if (cached != null) return cached;
    final descriptor = await _descriptor(assetId);
    if (descriptor == null) return null;
    final uri = _baseUri.resolve('${descriptor.hash}.bin');
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      final payload = response.bodyBytes;
      _remember(assetId, payload);
      return payload;
    } on Object {
      // 网络失败就当这张图暂时不可用，页面会显示缺图占位。
      return null;
    }
  }

  void _remember(String assetId, Uint8List payload) {
    if (_cache.length >= _cacheLimit) {
      _cache.remove(_cache.keys.first);
    }
    _cache[assetId] = payload;
  }

  Future<_AssetDescriptor?> _descriptor(String assetId) async {
    final rows = await _inner.select(
      'SELECT hash, width, height FROM assets '
      'WHERE asset_id = ? AND available = 1',
      [assetId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final hash = row['hash'];
    if (hash is! String || hash.isEmpty) return null;
    return _AssetDescriptor(
      hash: hash,
      width: (row['width'] as num?)?.toInt() ?? 0,
      height: (row['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class _AssetDescriptor {
  const _AssetDescriptor({
    required this.hash,
    required this.width,
    required this.height,
  });

  final String hash;
  final int width;
  final int height;
}

/// 把 sqlite3 wasm 的同步接口适配成异步的 [SqlExecutor]。
class _WasmSqlExecutor implements SqlExecutor {
  _WasmSqlExecutor(this._database, this._vfs, this._store);

  final CommonDatabase _database;
  final InMemoryFileSystem _vfs;
  final ContentBlobStore _store;

  @override
  Future<List<ContentRow>> select(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    // 题库的 SELECT 都是只读查询，直接走同步 API；外面包一层 Future 是为了
    // 和原生端共用 [SqlExecutor] 的异步签名。
    final rows = _database.select(sql, parameters);
    return <ContentRow>[for (final row in rows) Map<String, Object?>.from(row)];
  }

  @override
  Uint8List? blob(ContentRow row, String column) {
    final value = row[column];
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  @override
  Future<void> close() async {
    _database.close();
    // 把 ~178 MiB 的库字节从内存里放掉。内存 VFS 是我们自己创建的，
    // sqlite 关库不会清它。
    _vfs.fileData.clear();
    _store.close();
  }
}
