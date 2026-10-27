import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';
import 'content_repository.dart';

class FullContentRepository implements ContentRepository {
  FullContentRepository._(this._database, this._manifest);

  static const _databaseAsset = 'assets/content/content.sqlite';
  static const _manifestAsset = 'assets/content/content-manifest.json';

  final Database _database;
  final Map<String, dynamic> _manifest;

  static Future<FullContentRepository> open({
    AssetBundle? bundle,
    Directory? supportDirectory,
  }) async {
    final assetBundle = bundle ?? rootBundle;
    final manifestText = await assetBundle.loadString(_manifestAsset);
    final manifest = jsonDecode(manifestText) as Map<String, dynamic>;
    final version = manifest['contentVersion']?.toString() ?? 'unknown';
    final expectedBytes = (manifest['databaseBytes'] as num?)?.toInt() ?? 0;

    final support = supportDirectory ?? await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final databaseFile = File(
      '${support.path}${Platform.pathSeparator}content.sqlite',
    );
    final versionFile = File(
      '${support.path}${Platform.pathSeparator}content.version',
    );

    var needsCopy = !await databaseFile.exists();
    if (!needsCopy) {
      final installedVersion = await versionFile.exists()
          ? await versionFile.readAsString()
          : '';
      needsCopy =
          installedVersion.trim() != version ||
          (expectedBytes > 0 && await databaseFile.length() != expectedBytes);
    }

    if (needsCopy) {
      final temporary = File('${databaseFile.path}.building');
      if (await temporary.exists()) await temporary.delete();
      final output = await temporary.open(mode: FileMode.write);
      var written = 0;
      try {
        final parts = (manifest['databaseParts'] as List<dynamic>?) ?? const [];
        if (parts.isEmpty) {
          written += await _writeAsset(output, assetBundle, _databaseAsset);
        } else {
          for (final entry in parts) {
            final part = Map<String, dynamic>.from(entry as Map);
            final path = part['path']?.toString();
            if (path == null || path.isEmpty) {
              throw const FormatException('Content database part has no path');
            }
            written += await _writeAsset(output, assetBundle, path);
          }
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (expectedBytes > 0 && written != expectedBytes) {
        await temporary.delete();
        throw StateError(
          'Content database size mismatch: expected $expectedBytes, got $written',
        );
      }
      if (await databaseFile.exists()) await databaseFile.delete();
      await temporary.rename(databaseFile.path);
      await versionFile.writeAsString(version, flush: true);
    }

    final database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
    database.execute('PRAGMA query_only = ON');
    final integrity = database.select('PRAGMA quick_check').first.columnAt(0);
    if (integrity != 'ok') {
      database.close();
      throw StateError('Content database integrity check failed: $integrity');
    }
    return FullContentRepository._(database, manifest);
  }

  static Future<int> _writeAsset(
    RandomAccessFile output,
    AssetBundle bundle,
    String path,
  ) async {
    final data = await bundle.load(path);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await output.writeFrom(bytes);
    return bytes.length;
  }

  static FullContentRepository forTesting(
    Database database, {
    Map<String, dynamic> manifest = const {
      'contentVersion': 'test',
      'questionCount': 0,
      'paperCount': 0,
      'imageCount': 0,
    },
  }) {
    return FullContentRepository._(database, manifest);
  }

  @override
  Future<ContentStats> stats() async {
    return ContentStats(
      questionCount: _count('questions'),
      paperCount: _count('papers'),
      imageCount: _count('images'),
      contentVersion: _manifest['contentVersion']?.toString() ?? 'unknown',
    );
  }

  int _count(String table) {
    return _database.select('SELECT COUNT(*) FROM $table').first.columnAt(0)
        as int;
  }

  @override
  Future<List<Paper>> recentPapers({int limit = 5}) async {
    final rows = _database.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      ORDER BY year DESC, title ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_paperFromRow).toList(growable: false);
  }

  @override
  Future<List<Paper>> searchPapers({String query = '', int? year}) async {
    final normalized = query.trim();
    final rows = _database.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      WHERE (? = '' OR title LIKE ? OR region LIKE ?)
        AND (? IS NULL OR year = ?)
      ORDER BY year DESC, title ASC
      ''',
      [normalized, '%$normalized%', '%$normalized%', year, year],
    );
    return rows.map(_paperFromRow).toList(growable: false);
  }

  @override
  Future<Paper?> findPaper(String id) async {
    final rows = _database.select(
      '''
      SELECT id, title, year, region, paper_type, duration_seconds
      FROM papers
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );
    return rows.isEmpty ? null : _paperFromRow(rows.first);
  }

  @override
  Future<List<QuestionContent>> questionsForPaper(String paperId) async {
    final rows = _database.select(
      '''
      SELECT *
      FROM questions
      WHERE paper_id = ?
      ORDER BY sequence ASC, question_no ASC
      ''',
      [paperId],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  @override
  Future<QuestionContent?> findQuestion(String id) async {
    final rows = _database.select(
      'SELECT * FROM questions WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : _questionFromRow(rows.first);
  }

  @override
  Future<List<QuestionContent>> questionsByIds(Iterable<String> ids) async {
    final ordered = ids.toList(growable: false);
    if (ordered.isEmpty) return const [];
    final placeholders = List.filled(ordered.length, '?').join(',');
    final rows = _database.select(
      'SELECT * FROM questions WHERE id IN ($placeholders)',
      ordered,
    );
    final byId = {
      for (final row in rows) row['id'] as String: _questionFromRow(row),
    };
    return [for (final id in ordered) ?byId[id]];
  }

  @override
  Future<List<QuestionContent>> randomQuestions(
    int count, {
    String? module,
  }) async {
    final rows = _database.select(
      '''
      SELECT *
      FROM questions
      WHERE (? IS NULL OR module = ?)
      ORDER BY RANDOM()
      LIMIT ?
      ''',
      [module, module, count],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  @override
  Future<List<QuestionContent>> sequenceQuestions({int limit = 100}) async {
    final rows = _database.select(
      '''
      SELECT *
      FROM questions
      ORDER BY year ASC, paper_id ASC, sequence ASC, question_no ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map(_questionFromRow).toList(growable: false);
  }

  @override
  Future<Uint8List?> imageBytes(String assetId) async {
    final rows = _database.select(
      '''
      SELECT images.data
      FROM assets
      JOIN images ON images.hash = assets.hash
      WHERE assets.asset_id = ? AND assets.available = 1
      LIMIT 1
      ''',
      [assetId],
    );
    if (rows.isEmpty) return null;
    return rows.first['data'] as Uint8List;
  }

  Paper _paperFromRow(Row row) {
    return Paper(
      id: row['id'] as String,
      title: row['title'] as String,
      year: row['year'] as int,
      region: row['region'] as String,
      paperType: row['paper_type'] as String,
      durationSeconds: row['duration_seconds'] as int,
    );
  }

  QuestionContent _questionFromRow(Row row) {
    final options = (jsonDecode(row['options_json'] as String) as Map)
        .cast<String, String>();
    final correct = (jsonDecode(row['correct_json'] as String) as List)
        .cast<String>()
        .toSet();
    final material = (row['material_markup'] as String?)?.trim();
    return QuestionContent(
      id: row['id'] as String,
      paperId: row['paper_id'] as String,
      questionNo: row['question_no'] as int,
      module: row['module'] as String,
      stem: row['stem_markup'] as String,
      options: options,
      correctAnswers: correct,
      solution: row['solution_markup'] as String,
      material: material?.isNotEmpty == true ? material : null,
      searchStem: row['stem_text'] as String?,
    );
  }

  @override
  void close() => _database.close();
}
