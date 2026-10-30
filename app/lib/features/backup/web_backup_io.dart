import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web 端备份文件的浏览器出入口：导出走 `<a download>` 下载，导入走
/// 临时 `<input type="file">`。与 Android 端的 .gkbackup 文件格式完全一致，
/// 两端备份可互导。
///
/// 仅可从 Web 平台的代码路径引用（settings_platform_web.dart 经条件导入生效）。

Future<void> downloadBackupBytes(Uint8List bytes, String fileName) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/gzip'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // 立即 revoke：下载已经开始，Blob 数据已在下载进程里，不再依赖这个 URL。
  web.URL.revokeObjectURL(url);
}

/// 弹出文件选择框并读取一个备份文件；用户取消时返回 null。
Future<({String name, Uint8List bytes})?> pickBackupFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.gkbackup'
    ..multiple = false;
  final completer = Completer<web.File?>();
  void handleFiles(web.Event _) {
    final file = input.files?.item(0);
    if (!completer.isCompleted) completer.complete(file);
  }

  input.addEventListener('change', handleFiles.toJS);
  web.document.body!.appendChild(input);
  input.click();
  input.remove();

  final file = await completer.future;
  if (file == null) return null;
  final buffer = (await file.arrayBuffer().toDart).toDart.asUint8List();
  return (name: file.name, bytes: Uint8List.fromList(buffer));
}
