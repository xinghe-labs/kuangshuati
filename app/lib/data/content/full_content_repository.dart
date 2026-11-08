import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models.dart';
import 'bank_registry.dart';
import 'content_repository.dart';
import 'multi_bank_executor.dart';
import 'sql_content_repository.dart';
import 'sql_executor.dart';

/// 原生端（Android / iOS / 桌面）的题库实现。
///
/// 多题库共存：读 banks.json 登记表，把每套题库的 content.sqlite
/// ATTACH 合并后交给 [SqlContentRepository]。旧版单文件安装由
/// [BankRegistry.load] 自动迁移登记，不需要用户重新下载。
class FullContentRepository implements ContentRepository {
  FullContentRepository._(this._inner, this._registry);

  final SqlContentRepository _inner;
  final BankRegistry _registry;

  /// 当前登记的题库列表（题库管理页展示用）。
  List<BankInfo> get banks => _registry.banks;

  static Future<FullContentRepository> openInstalled({
    Directory? supportDirectory,
  }) async {
    final support = supportDirectory ?? await getApplicationSupportDirectory();
    final registry = BankRegistry(support.path);
    await registry.load();
    if (registry.banks.isEmpty) {
      throw StateError('Full content package is not installed');
    }
    final entries = <({String bankId, String path})>[
      for (final bank in registry.banks)
        (
          bankId: bank.id,
          path: registry.absoluteDatabasePath(bank),
        ),
    ];
    for (final entry in entries) {
      if (!File(entry.path).existsSync()) {
        throw StateError(
          'Bank database missing: ${entry.bankId} (${entry.path})',
        );
      }
    }
    final executor = await MultiBankSqlExecutor.open(entries);
    return FullContentRepository._(
      SqlContentRepository(executor, _summaryManifest(registry)),
      registry,
    );
  }

  /// 多库汇总的统计清单：stats() 的 contentVersion 兜底、Web 图片张数
  /// fallback 都从这里来。单库直接透传，多库拼接题数与套数。
  static Map<String, dynamic> _summaryManifest(BankRegistry registry) {
    if (registry.banks.length == 1) {
      final bank = registry.banks.first;
      return {
        'contentVersion': bank.contentVersion,
        'questionCount': bank.questionCount,
        'paperCount': bank.paperCount,
        'imageCount': bank.imageCount,
      };
    }
    return {
      'contentVersion':
          '${registry.banks.first.contentVersion} 等 ${registry.banks.length} 套题库',
      'questionCount': registry.totalQuestionCount,
      'paperCount': registry.totalPaperCount,
      'imageCount': null,
    };
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
      BankRegistry(''),
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
