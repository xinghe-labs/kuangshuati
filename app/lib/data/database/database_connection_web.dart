import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Web 端的用户库连接。
///
/// 浏览器里没有文件系统，`drift_flutter` 要求显式给出 wasm 与 worker 的位置，
/// 之后它会把数据库放进 OPFS（优先）或 IndexedDB。练习记录因此能跨刷新保留，
/// 清空浏览器数据才会丢。
QueryExecutor openUserDatabase({required String name}) => driftDatabase(
  name: name,
  web: DriftWebOptions(
    sqlite3Wasm: Uri.base.resolve('sqlite3.wasm'),
    driftWorker: Uri.base.resolve('drift_worker.js'),
  ),
);
