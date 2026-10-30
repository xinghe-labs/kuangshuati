import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web 端的 gzip 编解码：走浏览器的 `CompressionStream` / `DecompressionStream`。
///
/// `dart:io` 的 `gzip` 在浏览器里会抛 `Unsupported operation: _newZLibDeflate`，
/// 所以备份信封必须用这套实现。备份文件通常只有几十 KB，一次性处理即可。
Future<Uint8List> gzipEncodeBytes(Uint8List raw) async {
  final blob = web.Blob(<JSAny>[raw.toJS].toJS);
  final compressor = web.CompressionStream('gzip');
  final piping = blob.stream().pipeTo(compressor.writable);
  final response = web.Response(compressor.readable);
  final buffer = await response.arrayBuffer().toDart;
  await piping.toDart;
  return buffer.toDart.asUint8List();
}

Future<Uint8List> gzipDecodeBytes(Uint8List compressed) async {
  final blob = web.Blob(<JSAny>[compressed.toJS].toJS);
  final decompressor = web.DecompressionStream('gzip');
  final piping = blob.stream().pipeTo(decompressor.writable);
  final response = web.Response(decompressor.readable);
  final buffer = await response.arrayBuffer().toDart;
  await piping.toDart;
  return buffer.toDart.asUint8List();
}
