// Web 端题库的持久化存储。
//
// 为什么不用 `package:sqlite3` 自带的 `IndexedDbFileSystem`：
//
// 它的 `_readFiles()` 在一个 IndexedDB 只读事务里 `await` 了另一个 IDB
// 请求（`startRead` 内部的 `_readFile`）。Dart 的 `runWithNativeMicrotasks`
// 只能保住微任务，保不住跨宏任务的 IDB 事务，于是事务在 await 处失效，
// `startRead` 静默返回空缓冲区，`_memory.fileData['/database']` 的长度变成 0。
// 表现出来就是：IndexedDB 里数据完整（files.length = 187015168、
// 45658 个 4096 字节的块都在），但重新打开页面后 `xFileSize()` 读到 0，
// sqlite 打开的是空库，`page_count` = 0、`sqlite_master` 没有表。
//
// 所以这里自己管存取：
//
// * 把字节切成 50 MiB 的块，分片存在 IndexedDB；
//   （Edge/Chromium 的 IndexedDB 对单个 value 有 128 MiB 限制
//   `max=133169152`，Firefox 也有类似上限，50 MiB 单块既能放进去
//   又避免结构化克隆报错。）
// * 一次性把所有块拼起来交给 `InMemoryFileSystem`，sqlite 只面对一个
//   同步的内存文件，没有异步 VFS 的坑。
//
// 代价是每次打开页面要把 ~178 MiB 从 IndexedDB 读进内存。实测这是可以接受
// 的：读完加打开 sqlite 约 1 秒，换来的是「刷新后不再重新下载」。
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 题库字节在 IndexedDB 里的分片大小。
const int _chunkSize = 50 * 1024 * 1024;

/// 浏览器里存题库字节的 IndexedDB 封装。
class ContentBlobStore {
  ContentBlobStore._(this._database);

  static const String databaseName = 'kuangshuati_content_v2';
  static const String storeName = 'blobs';
  static const String manifestKey = 'manifest';

  /// 题库清单（contentVersion、题数等）单独存一个键。
  ///
  /// 不能只依赖打开页面时去 fetch 远端 manifest：离线、或远端暂时不可达时
  /// 版本号会退化成 `unknown`，`updateAvailable` 也就永远不成立。
  static const String infoKey = 'info';

  final web.IDBDatabase _database;

  /// 打开（必要时创建）存储库。
  static Future<ContentBlobStore> open() async {
    final request = web.window.indexedDB.open(databaseName, 1);

    request.onupgradeneeded = ((web.Event event) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(storeName)) {
        database.createObjectStore(storeName);
      }
    }).toJS;

    final database = await _awaitOpen(request);
    return ContentBlobStore._(database);
  }

  /// 读出之前存的整个字节；没有或已损坏则返回 null。
  ///
  /// 分片清单存成 JSON 字符串而不是 JS 对象：字符串用 `jsonDecode` 解就行，
  /// 不需要动态属性访问，也就不会依赖 `dart:js_interop_unsafe`。
  Future<Uint8List?> readAll() async {
    final manifestJson = await readChunkManifest();
    if (manifestJson == null) return null;
    final int count;
    final int totalLength;
    try {
      final decoded = jsonDecode(manifestJson);
      if (decoded is! Map<String, dynamic>) return null;
      count = (decoded['count'] as num?)?.toInt() ?? 0;
      totalLength = (decoded['length'] as num?)?.toInt() ?? 0;
    } on Object {
      // 清单坏了当作没缓存，让上层重新下载。
      await clear();
      return null;
    }
    if (count <= 0 || totalLength <= 0) return null;

    final out = BytesBuilder();
    for (var i = 0; i < count; i++) {
      final value = await _read('chunk$i');
      if (value == null) {
        // 中途丢了块，说明上次写没完成，把坏缓存清了。
        await clear();
        return null;
      }
      if (value.isA<JSArrayBuffer>()) {
        out.add((value as JSArrayBuffer).toDart.asUint8List());
      } else if (value.isA<JSUint8Array>()) {
        // IndexedDB 取回的是 Uint8Array（写入时 `Uint8List.toJS` 就是这个），
        // 不是裸 ArrayBuffer。
        out.add((value as JSUint8Array).toDart);
      } else {
        // Blob 兵底（旧实现写入的可能是 Blob）。
        final blob = value as web.Blob;
        final buffer = await blob.arrayBuffer().toDart;
        out.add(buffer.toDart.asUint8List());
      }
    }
    final bytes = out.toBytes();
    if (bytes.length != totalLength) {
      await clear();
      return null;
    }
    return bytes;
  }

  /// 覆盖写入字节（先清之前的，再写）。
  ///
  /// 两处坑：
  ///
  /// 1. `Uint8List.sublistView` 与原缓冲**共享**同一个 ArrayBuffer，而
  ///    IndexedDB 的结构化克隆会序列化整个底层缓冲。178 MiB 的库即使只写
  ///    50 MiB 切片，也会报 `serialized ... too large (size=187015224,
  ///    max=133169152)`。所以每片必须 `Uint8List.fromList` 复制一份。
  /// 2. 写入可能被事务 abort（配额、超限等），此时 request 的 `onerror`
  ///    不一定触发。必须同时等事务的 `oncomplete`/`onabort`，否则就是死等。
  Future<void> writeAll(Uint8List bytes) async {
    await clear();
    final count = (bytes.length + _chunkSize - 1) ~/ _chunkSize;
    for (var i = 0; i < count; i++) {
      final start = i * _chunkSize;
      final end = (start + _chunkSize > bytes.length)
          ? bytes.length
          : start + _chunkSize;
      // 复制成独立缓冲，不带 178 MiB 的尾巴。
      final chunk = Uint8List.fromList(
        Uint8List.sublistView(bytes, start, end),
      );
      await _write('chunk$i', chunk.toJS);
    }
    final manifest = jsonEncode({'count': count, 'length': bytes.length});
    // manifest 最后写：读的时候以它为“写完了”的标志。
    await _write(manifestKey, manifest.toJS);
  }

  /// 删除已存的字节（题库损坏或版本变更时用）。
  Future<void> clear() async {
    final tx = _database.transaction(storeName.toJS, 'readwrite');
    final done = _awaitTransaction(tx);
    tx.objectStore(storeName).clear();
    await done;
  }

  /// 读出分片清单（JSON 字符串）；没存过则返回 null。
  Future<String?> readChunkManifest() async {
    final value = await _read(manifestKey);
    if (value == null) return null;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    return null;
  }

  /// 把题库版本等信息存成 JSON 字符串，下次打开直接读回。
  Future<void> writeContentInfo(String json) => _write(infoKey, json.toJS);

  /// 读出题库版本等信息；没存过则返回 null。
  Future<String?> readContentInfo() async {
    final value = await _read(infoKey);
    if (value == null) return null;
    if (value.isA<JSString>()) return (value as JSString).toDart;
    return null;
  }

  /// 单个键的读（独立只读事务，只等这一个请求）。
  Future<JSAny?> _read(String key) {
    final tx = _database.transaction(storeName.toJS, 'readonly');
    return _awaitRequest<JSAny?>(tx.objectStore(storeName).get(key.toJS));
  }

  /// 单个键的写（独立读写事务）。
  ///
  /// 同时等 request 与 transaction：超限/配额错误往往表现为事务 abort，
  /// 只等 request 会永远等不到结果。
  Future<void> _write(String key, JSAny value) async {
    final tx = _database.transaction(storeName.toJS, 'readwrite');
    final done = _awaitTransaction(tx);
    tx.objectStore(storeName).put(value, key.toJS);
    await done;
  }

  void close() => _database.close();

  static Future<T> _awaitRequest<T extends JSAny?>(web.IDBRequest request) {
    final completer = Completer<T>();
    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) completer.complete(request.result as T);
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        final message = request.error?.message ?? 'IndexedDB 请求失败';
        completer.completeError(StateError(message));
      }
    }).toJS;
    return completer.future;
  }

  static Future<web.IDBDatabase> _awaitOpen(web.IDBOpenDBRequest request) {
    final completer = Completer<web.IDBDatabase>();
    request.onsuccess = ((web.Event event) {
      if (!completer.isCompleted) {
        completer.complete(request.result as web.IDBDatabase);
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        final message = request.error?.message ?? 'IndexedDB 打开失败';
        completer.completeError(StateError(message));
      }
    }).toJS;
    return completer.future;
  }

  static Future<void> _awaitTransaction(web.IDBTransaction tx) {
    final completer = Completer<void>();
    tx.oncomplete = ((web.Event event) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    tx.onerror = ((web.Event event) {
      if (!completer.isCompleted) {
        final message = tx.error?.message ?? 'IndexedDB 事务失败';
        completer.completeError(StateError(message));
      }
    }).toJS;
    tx.onabort = ((web.Event event) {
      if (!completer.isCompleted) {
        final message = tx.error?.message ?? 'IndexedDB 事务被中止';
        completer.completeError(StateError(message));
      }
    }).toJS;
    return completer.future;
  }
}
