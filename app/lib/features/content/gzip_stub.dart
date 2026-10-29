import 'dart:typed_data';

/// 非 Web 平台的占位实现：原生端用完整的 SQLite 题库文件，不需要解压这一层。
Future<Uint8List> gunzipBytes(Uint8List compressed) async {
  throw UnsupportedError('gunzipBytes 只在 Web 端可用');
}
