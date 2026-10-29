import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';
import 'content_repository.dart';

class FullContentRepository implements ContentRepository {
  FullContentRepository._(this._database, this._manifest);

  final Database _database;
  final Map<String, dynamic> _manifest;

  static Future<FullContentRepository> openInstalled({
    Directory? supportDirectory,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final manifestFile = File(
      '${support.path}${Platform.pathSeparator}content-installed.json',
    );
    final databaseFile = File(
      '${support.path}${Platform.pathSeparator}content.sqlite',
    );
    if (!await manifestFile.exists() || !await databaseFile.exists()) {
      throw StateError('Full content package is not installed');
    }
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final expectedBytes = (manifest['databaseBytes'] as num?)?.toInt() ?? 0;
    if (expectedBytes > 0 && await databaseFile.length() != expectedBytes) {
      throw StateError(
        'Installed content database size does not match manifest',
      );
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
    if (count <= 0) return const <QuestionContent>[];
    // 开发文档 §9.1 要求“材料组作为抽题最小单位”。但真实题库里有两类例外，
    // 都按单题抽，否则会一次抽出整库或整节：
    //   1) 43 904 道题的上游 groupId 为空，全部塔缩成一个伪组（group_id=''）；
    //   2) 存在 35/50/60 题的超大材料组，装不进 20 题练习。
    // 只有“整组能完整装进本次题量”的材料组才整组抽。
    final units = _database.select(
      '''
      SELECT group_id, COUNT(*) AS n
      FROM questions
      WHERE (? IS NULL OR module = ?) AND group_id <> ''
      GROUP BY group_id
      HAVING COUNT(*) <= ?
      ORDER BY RANDOM()
      ''',
      [module, module, count],
    );
    final chosenGroups = <String>[];
    var planned = 0;
    for (final row in units) {
      if (planned >= count) break;
      chosenGroups.add(row['group_id'] as String);
      planned += row['n'] as int;
    }
    final picked = <QuestionContent>[];
    if (chosenGroups.isNotEmpty) {
      final placeholders = List.filled(chosenGroups.length, '?').join(', ');
      picked.addAll(
        _database
            .select(
              '''
              SELECT *
              FROM questions
              WHERE group_id IN ($placeholders) AND (? IS NULL OR module = ?)
              ORDER BY group_id, sequence, question_no
              ''',
              [...chosenGroups, module, module],
            )
            .map(_questionFromRow),
      );
    }
    if (picked.length < count) {
      // 剩余的由无材料分组的单题和装不进本组练习的大组补足，逐个随机。
      final exclude = chosenGroups.isEmpty
          ? ''
          : 'AND group_id NOT IN (${List.filled(chosenGroups.length, '?').join(', ')})';
      picked.addAll(
        _database
            .select(
              '''
              SELECT *
              FROM questions
              WHERE (? IS NULL OR module = ?) $exclude
              ORDER BY RANDOM()
              LIMIT ?
              ''',
              [module, module, ...chosenGroups, count - picked.length],
            )
            .map(_questionFromRow),
      );
    }
    return picked;
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
    final image = await imageWithSize(assetId);
    return image?.bytes;
  }

  @override
  Future<ContentImage?> imageWithSize(String assetId) async {
    final rows = _database.select(
      '''
      SELECT images.data, images.width, images.height
      FROM assets
      JOIN images ON images.hash = assets.hash
      WHERE assets.asset_id = ? AND assets.available = 1
      LIMIT 1
      ''',
      [assetId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ContentImage(
      bytes: row['data'] as Uint8List,
      width: row['width'] as int,
      height: row['height'] as int,
    );
  }

  /// assetId → 原始高度，命中后永不再查。
  final Map<String, int> _heightCache = {};

  @override
  Map<String, int> imageHeightsSync(Iterable<String> assetIds) {
    final requested = assetIds.toSet();
    final missing = requested
        .where((id) => !_heightCache.containsKey(id))
        .toList();
    if (missing.isNotEmpty) {
      final placeholders = List.filled(missing.length, '?').join(',');
      for (final row in _database.select(
        'SELECT asset_id, height FROM assets '
        'WHERE available = 1 AND asset_id IN ($placeholders)',
        missing,
      )) {
        final height = row['height'];
        if (height is int && height > 0) {
          _heightCache[row['asset_id'] as String] = height;
        }
      }
      for (final id in missing) {
        _heightCache.putIfAbsent(id, () => 0);
      }
    }
    return {
      for (final id in requested)
        if ((_heightCache[id] ?? 0) > 0) id: _heightCache[id]!,
    };
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
      sequence: row['sequence'] as int,
      module: row['module'] as String,
      stem: row['stem_markup'] as String,
      options: options,
      correctAnswers: correct,
      solution: row['solution_markup'] as String,
      material: material?.isNotEmpty == true ? material : null,
      searchStem: row['stem_text'] as String?,
      groupId: row['group_id'] as String? ?? '',
    );
  }

  @override
  void close() => _database.close();
}
