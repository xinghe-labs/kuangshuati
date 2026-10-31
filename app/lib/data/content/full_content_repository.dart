import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';
import 'content_repository.dart';
import 'sql_content_repository.dart';
import 'sql_executor.dart';

/// 原生端（Android / iOS / 桌面）的题库实现：直接用 `package:sqlite3` 读本地
/// content.sqlite。查询逻辑在 [SqlContentRepository] 里，与 Web 端共用。
class FullContentRepository implements ContentRepository {
  FullContentRepository._(this._inner);

  final SqlContentRepository _inner;

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
    return FullContentRepository._(
      SqlContentRepository(_NativeSqlExecutor(database), manifest),
    );
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
    return FullContentRepository._(
      SqlContentRepository(_NativeSqlExecutor(database), manifest),
    );
  }

  @override
  Future<ContentStats> stats() => _inner.stats();

  @override
  Future<List<Paper>> recentPapers({int limit = 5}) =>
      _inner.recentPapers(limit: limit);

  @override
  Future<List<Paper>> searchPapers({String query = '', int? year}) =>
      _inner.searchPapers(query: query, year: year);

  @override
  Future<Paper?> findPaper(String id) => _inner.findPaper(id);

  @override
  Future<List<QuestionContent>> questionsForPaper(String paperId) =>
      _inner.questionsForPaper(paperId);

  @override
  Future<QuestionContent?> findQuestion(String id) => _inner.findQuestion(id);

  @override
  Future<List<QuestionContent>> questionsByIds(Iterable<String> ids) =>
      _inner.questionsByIds(ids);

  @override
  Future<List<QuestionContent>> randomQuestions(int count, {String? module}) =>
      _inner.randomQuestions(count, module: module);

  @override
  Future<List<QuestionContent>> sequenceQuestions({
    int limit = 100,
    Iterable<String> excludeIds = const [],
  }) => _inner.sequenceQuestions(limit: limit, excludeIds: excludeIds);

  @override
  Future<List<QuestionContent>> searchQuestions(
    String query, {
    int limit = 200,
  }) => _inner.searchQuestions(query, limit: limit);

  @override
  Future<Uint8List?> imageBytes(String assetId) => _inner.imageBytes(assetId);

  @override
  Future<ContentImage?> imageWithSize(String assetId) =>
      _inner.imageWithSize(assetId);

  @override
  Future<Map<String, int>> imageHeights(Iterable<String> assetIds) =>
      _inner.imageHeights(assetIds);

  @override
  Future<void> close() => _inner.close();
}

class _NativeSqlExecutor implements SqlExecutor {
  _NativeSqlExecutor(this._database);

  final Database _database;

  @override
  Future<List<ContentRow>> select(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    return _database
        .select(sql, parameters)
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
  }

  @override
  Uint8List? blob(ContentRow row, String column) {
    final value = row[column];
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    return null;
  }

  @override
  Future<void> close() async => _database.close();
}
