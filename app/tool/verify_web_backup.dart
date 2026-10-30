// 反向跨端校验：读取浏览器（CompressionStream）生成的 .gkbackup，
// 用原生端的 gzip 实现解开，并走一遍完整的信封校验逻辑。
//
// 与 artifacts/cross-backup-e2e.cjs 配合：那边产出 artifacts/web-backup-sample.gkbackup，
// 这里验证 Dart 侧能否读懂。
import 'dart:convert';
import 'dart:io';

import 'package:kuangshuati/features/backup/gzip_codec_io.dart' as codec;

Future<void> main() async {
  final file = File('../artifacts/web-backup-sample.gkbackup');
  if (!file.existsSync()) {
    stderr.writeln('缺少 ${file.path}，先跑 node artifacts/cross-backup-e2e.cjs');
    exit(1);
  }
  final bytes = await file.readAsBytes();
  stdout.writeln('读取 ${file.path}：${bytes.length} 字节');

  if (bytes[0] != 0x1f || bytes[1] != 0x8b) {
    stderr.writeln('FAIL 不是标准 gzip');
    exit(1);
  }
  stdout.writeln('OK   标准 gzip（magic 1f 8b）');

  final raw = await codec.gzipDecodeBytes(bytes);
  final decoded = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
  final manifest = decoded['manifest']! as Map<String, Object?>;
  if (manifest['format'] != 'kuangshuati.gkbackup') {
    stderr.writeln('FAIL format=${manifest['format']}');
    exit(1);
  }
  stdout.writeln('OK   format=${manifest['format']} version=${manifest['formatVersion']}');

  final tables = decoded['tables']! as Map<String, Object?>;
  final sessions = tables['practice_sessions']! as Map<String, Object?>;
  final rows = sessions['rows']! as List;
  stdout.writeln('OK   practice_sessions 列=${sessions['columns']} 行数=${rows.length}');
  stdout.writeln('\n结论：原生端能完整解析浏览器生成的备份（反向跨端 OK）');
}
