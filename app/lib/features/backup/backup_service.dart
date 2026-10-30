import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../data/database/app_database.dart';
import 'gzip_codec_io.dart'
    if (dart.library.js_interop) 'gzip_codec_web.dart' as gzip_codec;

/// 用户数据的备份与恢复（开发文档 §15）。
///
/// 容器是 gzip 压缩的 JSON，扩展名 `.gkbackup`，内含：
/// - `manifest`：格式版本、导出时间、应用版本、题库版本、各表行数、负载摘要；
/// - `tables`：用户库里全部用户表的原始行（列名 + 行值）。
///
/// 之所以导出逻辑行而不是直接复制 `user.db` 文件：一次恢复可能跨越多个
/// 应用版本，直接换文件会在 schema 升级后打不开；按列名恢复时只取当前库里
/// 存在的列，多出的列丢弃、缺失的列走默认值。
class BackupService {
  BackupService({
    required this._database,
    required this._directoryOf,
    required this._appVersionLabel,
    required this._contentInfo,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _database;
  final Future<Directory> Function() _directoryOf;
  final Future<String> Function() _appVersionLabel;
  final Future<Map<String, Object?>> Function() _contentInfo;
  final DateTime Function() _now;

  static const String format = 'kuangshuati.gkbackup';
  static const int formatVersion = 1;
  static const String extension = '.gkbackup';

  /// 只备份用户数据，不含题库（题库图片和内容库另有安装/更新流程）。
  static const List<String> userTables = [
    'practice_sessions',
    'session_questions',
    'session_answers',
    'review_items',
    'favorites',
    'daily_stats',
    'module_stats',
    'app_settings',
  ];

  Future<Directory> _backupDirectory() async {
    final root = await _directoryOf();
    final directory = Directory('${root.path}/backups');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// 构造备份信封（gzip JSON）。Android/iOS 写入文件，Web 触发浏览器下载，
  /// 两端共用同一份字节与文件名，保证备份文件跨端可互导。
  Future<BackupEnvelope> buildEnvelope() async {
    final createdAt = _now().toUtc();
    final tables = await _dumpTables();
    final payload = jsonEncode(tables);
    final counts = {
      for (final entry in tables.entries) entry.key: entry.value.rows.length,
    };
    final manifest = <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': await _appVersionLabel(),
      'content': await _contentInfo(),
      'counts': counts,
      'payloadSha256': sha256.convert(utf8.encode(payload)).toString(),
    };
    final body = jsonEncode({'manifest': manifest, 'tables': tables});
    return BackupEnvelope(
      bytes: await gzip_codec.gzipEncodeBytes(
        Uint8List.fromList(utf8.encode(body)),
      ),
      fileName: _fileNameFor(createdAt),
      manifest: manifest,
    );
  }

  /// 导出到 `<应用文档目录>/backups/`，返回落盘文件。
  Future<File> export() async {
    final directory = await _backupDirectory();
    final envelope = await buildEnvelope();
    final file = File('${directory.path}/${envelope.fileName}');
    await file.writeAsBytes(envelope.bytes, flush: true);
    await _pruneOldBackups(keep: 5);
    return file;
  }

  String _fileNameFor(DateTime createdAt) {
    final local = createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${local.year}${two(local.month)}${two(local.day)}'
        '-${two(local.hour)}${two(local.minute)}${two(local.second)}';
    return 'kst-$stamp$extension';
  }

  /// 本机备份目录里的文件，按修改时间从新到旧。
  Future<List<File>> listBackups() async {
    final directory = await _backupDirectory();
    if (!await directory.exists()) return const [];
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith(extension))
        .cast<File>()
        .toList();
    final withTime = await Future.wait(
      files.map((file) async => (file: file, at: await file.lastModified())),
    );
    withTime.sort((a, b) => b.at.compareTo(a.at));
    return [for (final item in withTime) item.file];
  }

  /// 仅供界面展示的文件描述，如 `kst-20260103-101500.gkbackup（42.1 KB）`。
  String describe(File file) {
    final name = file.uri.pathSegments.last;
    final size = file.lengthSync();
    final label = size < 1024
        ? '$size B'
        : size < 1024 * 1024
        ? '${(size / 1024).toStringAsFixed(1)} KB'
        : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    return '$name（$label）';
  }

  /// 解析并校验备份文件；格式不对或摘要不匹配时抛出 [BackupFormatException]。
  Future<BackupSnapshot> read(File file) async {
    return parseBackupBytes(await file.readAsBytes(), sourceName: file.path);
  }

  Future<BackupSnapshot> parseBackupBytes(
    Uint8List bytes, {
    String sourceName = '备份文件',
  }) async {
    final List<int> raw;
    try {
      raw = await gzip_codec.gzipDecodeBytes(bytes);
    } catch (error) {
      throw BackupFormatException('$sourceName 不是有效的备份文件（压缩数据损坏）');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } catch (error) {
      throw BackupFormatException('$sourceName 内容不是有效的 JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw BackupFormatException('$sourceName 缺少备份结构');
    }
    if (decoded['manifest'] is! Map<String, Object?>) {
      throw BackupFormatException('$sourceName 缺少 manifest');
    }
    final manifest = decoded['manifest']! as Map<String, Object?>;
    if (manifest['format'] != format) {
      throw BackupFormatException('$sourceName 不是狂刷题备份文件');
    }
    final version = manifest['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw BackupFormatException('$sourceName 来自更新版本的应用，当前版本无法恢复');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw BackupFormatException('$sourceName 缺少数据表');
    }
    final expected = manifest['payloadSha256'];
    final actual = sha256.convert(utf8.encode(jsonEncode(tables))).toString();
    if (expected is! String || expected != actual) {
      throw BackupFormatException('$sourceName 校验失败，文件可能已损坏');
    }
    final parsedTables = <String, BackupTable>{};
    for (final entry in tables.entries) {
      if (!userTables.contains(entry.key)) continue;
      final value = entry.value;
      if (value is! Map<String, Object?>) continue;
      final columns = value['columns'];
      final rows = value['rows'];
      if (columns is! List || rows is! List) continue;
      parsedTables[entry.key] = BackupTable(
        columns: columns.map((column) => '$column').toList(),
        rows: [
          for (final row in rows)
            if (row is List) row,
        ],
      );
    }
    return BackupSnapshot(
      manifest: manifest,
      tables: parsedTables,
      byteSize: bytes.length,
      sourceName: sourceName,
    );
  }

  /// 恢复：先自动备份当前数据，再在一个事务里整体替换；失败时事务回滚。
  Future<BackupRestoreOutcome> restore(
    BackupSnapshot snapshot, {
    bool keepSafetyBackup = true,
  }) async {
    final safetyBackup = keepSafetyBackup ? await export() : null;
    final currentColumns = <String, Set<String>>{};
    for (final table in userTables) {
      currentColumns[table] = await _columnNames(table);
    }
    try {
      await _database.transaction(() async {
        for (final table in userTables) {
          await _database.customStatement('DELETE FROM $table');
        }
        for (final entry in snapshot.tables.entries) {
          final available = currentColumns[entry.key];
          if (available == null) continue;
          final indexes = <int>[];
          final columns = <String>[];
          for (var index = 0; index < entry.value.columns.length; index++) {
            final column = entry.value.columns[index];
            if (available.contains(column)) {
              indexes.add(index);
              columns.add(column);
            }
          }
          if (columns.isEmpty) continue;
          final placeholders = List.filled(columns.length, '?').join(', ');
          final sql =
              'INSERT INTO ${entry.key} (${columns.join(', ')}) '
              'VALUES ($placeholders)';
          for (final row in entry.value.rows) {
            if (row.length != entry.value.columns.length) continue;
            final args = [
              for (final index in indexes)
                switch (row[index]) {
                  final num value => value,
                  final String value => value,
                  final bool value => value ? 1 : 0,
                  _ => null,
                },
            ];
            await _database.customStatement(sql, args);
          }
        }
      });
    } catch (error) {
      throw BackupRestoreException('恢复失败：$error', safetyBackup: safetyBackup);
    }
    return BackupRestoreOutcome(snapshot: snapshot, safetyBackup: safetyBackup);
  }

  /// 当前数据的规模，用于导入前告知用户“将要替换什么”。
  Future<BackupCounts> currentCounts() async {
    Future<int> count(String sql) async {
      final row = await _database.customSelect(sql).getSingle();
      return (row.data.values.first as num?)?.toInt() ?? 0;
    }

    return BackupCounts(
      sessions: await count('SELECT COUNT(*) FROM practice_sessions'),
      activeSessions: await count(
        "SELECT COUNT(*) FROM practice_sessions WHERE status = 'active'",
      ),
      answeredQuestions: await count(
        'SELECT COUNT(*) FROM session_answers WHERE submitted = 1',
      ),
      reviewItems: await count('SELECT COUNT(*) FROM review_items'),
      favorites: await count('SELECT COUNT(*) FROM favorites'),
      days: await count('SELECT COUNT(*) FROM daily_stats'),
    );
  }

  Future<void> _pruneOldBackups({required int keep}) async {
    final files = await listBackups();
    if (files.length <= keep) return;
    for (final file in files.sublist(keep)) {
      try {
        await file.delete();
      } catch (_) {
        // 清理失败不影响这次备份本身。
      }
    }
  }

  Future<Map<String, BackupTable>> _dumpTables() async {
    final tables = <String, BackupTable>{};
    for (final table in userTables) {
      final columns = (await _columnNames(table)).toList();
      final result = await _database.customSelect('SELECT * FROM $table').get();
      final rows = <List<Object?>>[];
      for (final row in result) {
        rows.add([for (final column in columns) row.data[column]]);
      }
      tables[table] = BackupTable(columns: columns, rows: rows);
    }
    return tables;
  }

  Future<Set<String>> _columnNames(String table) async {
    final result = await _database
        .customSelect('PRAGMA table_info($table)')
        .get();
    return {for (final row in result) '${row.data['name']}'};
  }
}

class BackupEnvelope {
  const BackupEnvelope({
    required this.bytes,
    required this.fileName,
    required this.manifest,
  });

  final Uint8List bytes;
  final String fileName;
  final Map<String, Object?> manifest;
}

class BackupTable {
  const BackupTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Object?>> rows;

  Map<String, Object?> toJson() => {'columns': columns, 'rows': rows};
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.manifest,
    required this.tables,
    required this.byteSize,
    required this.sourceName,
  });

  final Map<String, Object?> manifest;
  final Map<String, BackupTable> tables;
  final int byteSize;
  final String sourceName;

  String get createdAtLabel {
    final raw = manifest['createdAt'];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null) return '未知时间';
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String get appVersion => '${manifest['appVersion'] ?? '未知版本'}';

  String get contentVersion {
    final content = manifest['content'];
    if (content is Map && content['contentVersion'] != null) {
      return '${content['contentVersion']}';
    }
    return '未知题库';
  }

  BackupCounts get counts {
    int rows(String table) => tables[table]?.rows.length ?? 0;
    var active = 0;
    final sessions = tables['practice_sessions'];
    if (sessions != null) {
      final statusIndex = sessions.columns.indexOf('status');
      if (statusIndex >= 0) {
        for (final row in sessions.rows) {
          if (row.length > statusIndex && row[statusIndex] == 'active') {
            active++;
          }
        }
      }
    }
    var answered = 0;
    final answers = tables['session_answers'];
    if (answers != null) {
      final submittedIndex = answers.columns.indexOf('submitted');
      if (submittedIndex >= 0) {
        for (final row in answers.rows) {
          final value = row.length > submittedIndex
              ? row[submittedIndex]
              : null;
          if (value == 1 || value == '1' || value == true) answered++;
        }
      }
    }
    return BackupCounts(
      sessions: rows('practice_sessions'),
      activeSessions: active,
      answeredQuestions: answered,
      reviewItems: rows('review_items'),
      favorites: rows('favorites'),
      days: rows('daily_stats'),
    );
  }

  String get byteSizeLabel {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class BackupCounts {
  const BackupCounts({
    required this.sessions,
    required this.activeSessions,
    required this.answeredQuestions,
    required this.reviewItems,
    required this.favorites,
    required this.days,
  });

  final int sessions;
  final int activeSessions;
  final int answeredQuestions;
  final int reviewItems;
  final int favorites;
  final int days;

  bool get isEmpty =>
      sessions == 0 && reviewItems == 0 && favorites == 0 && days == 0;

  List<(String, int)> get entries => [
    ('练习记录', sessions),
    ('进行中', activeSessions),
    ('已作答题目', answeredQuestions),
    ('错题本', reviewItems),
    ('收藏', favorites),
    ('统计天数', days),
  ];
}

class BackupRestoreOutcome {
  const BackupRestoreOutcome({required this.snapshot, this.safetyBackup});

  final BackupSnapshot snapshot;
  final File? safetyBackup;
}

class BackupFormatException implements Exception {
  BackupFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupRestoreException implements Exception {
  BackupRestoreException(this.message, {this.safetyBackup});

  final String message;
  final File? safetyBackup;

  @override
  String toString() => message;
}
