import 'dart:io';
import 'dart:typed_data';

/// 原生端的 gzip 编解码：直接用 `dart:io` 的 ZLib 实现。
///
/// 签名与 Web 端实现保持一致（返回 Future），这样调用方只写一份代码。
Future<Uint8List> gzipEncodeBytes(Uint8List raw) async =>
    Uint8List.fromList(gzip.encode(raw));

Future<Uint8List> gzipDecodeBytes(Uint8List compressed) async =>
    Uint8List.fromList(gzip.decode(compressed));
