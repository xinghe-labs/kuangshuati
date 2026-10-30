// 用原生实现（dart:io gzip）生成一份备份字节，供浏览器端解析验证。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kuangshuati/features/backup/gzip_codec_io.dart' as codec;

Future<void> main() async {
  final body = jsonEncode({
    'manifest': {
      'format': 'kuangshuati.gkbackup',
      'formatVersion': 1,
      'createdAt': '2026-10-30T02:00:00.000Z',
      'appVersion': '1.0.6 (7)',
      'content': {'contentVersion': '2026-10-25', 'questionCount': 58890},
      'counts': {'practice_sessions': 1, 'session_answers': 2},
      'payloadSha256': '',
    },
    'tables': {
      'practice_sessions': {
        'columns': ['id', 'mode'],
        'rows': [[1, 'random']],
      },
    },
  });
  final bytes = await codec.gzipEncodeBytes(
    Uint8List.fromList(utf8.encode(body)),
  );
  final file = File('artifacts/native-backup-sample.gkbackup');
  await file.writeAsBytes(bytes);
  stdout.writeln('wrote ${file.path} ${bytes.length} bytes');
}
