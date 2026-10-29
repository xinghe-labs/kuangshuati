import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 用浏览器的 `DecompressionStream('gzip')` 解压题库包。
///
/// 为什么不用 Dart 侧的 gzip 实现：核心库解压后约 178 MiB，纯 Dart 解压要在
/// 主线程跑几十秒并占满内存；浏览器的实现是原生的，而且能流式处理。
///
/// 这段代码只能在 Web 上编译，所以放在单独的库文件里，由
/// `web_content_manager.dart` 条件导入。
Future<Uint8List> gunzipBytes(Uint8List compressed) async {
  final blob = web.Blob(<JSAny>[compressed.toJS].toJS);
  final decompressor = web.DecompressionStream('gzip');
  // Blob 的流接进解压器，再从解压器的 readable 端读回来。
  final piping = blob.stream().pipeTo(decompressor.writable);
  final response = web.Response(decompressor.readable);
  final buffer = await response.arrayBuffer().toDart;
  await piping.toDart;
  return buffer.toDart.asUint8List();
}
