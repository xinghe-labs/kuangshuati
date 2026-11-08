import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../data/content/bank_registry.dart';
import 'content_import_models.dart';

// 题库导入的纯数据类型在 content_import_models.dart（web 图不触 sqlite3），
// 这里 re-export 保证既有 import 方（content_manager.dart、测试）不用改。
export 'content_import_models.dart';

/// 本地导入题库的 JSON 格式约定（见 docs/question-bank-format.md）。
const _bankFormat = 'kuangshuati-bank';
const _bankFormatVersion = 2;
/// 历史兼容：v1 与 v2 的唯一差异是 v2 允许自评题（options/answer 同时省略）。
const _acceptedFormatVersions = {1, _bankFormatVersion};

/// 单个题库 JSON 文件的大小上限：解析期字符串 + 解码结构 + 解码后图片
/// 大约是文件体积的 3 倍内存，64MB 文件在低端机上也够安全。
const _maxImportFileBytes = 64 * 1024 * 1024;

/// 把官方下载管线之外的自制题库 JSON 装进应用：
/// 解析校验 → 建 content.sqlite → 完整性检查 → 与下载安装同一套原子落盘。
class ContentImportService {
  ContentImportService({this.supportDirectory, this.temporaryDirectory});

  final Directory? supportDirectory;
  final Directory? temporaryDirectory;

  Future<Directory> get _support async =>
      supportDirectory ?? await getApplicationSupportDirectory();

  Future<Directory> get _temporary async =>
      temporaryDirectory ?? await getTemporaryDirectory();

  Future<ImportedBankSummary> importFromFile(
    String path, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    void report(double progress, String stage) =>
        onProgress?.call(progress, stage);
    final file = File(path);
    if (!await file.exists()) {
      throw const ContentImportException('找不到所选的题库文件');
    }
    final fileBytes = await file.length();
    if (fileBytes > _maxImportFileBytes) {
      throw ContentImportException(
        '题库文件过大（${(fileBytes / 1024 / 1024).toStringAsFixed(0)}MB），'
        '单文件请控制在 64MB 以内',
      );
    }
    report(0.05, '正在读取题库文件');
    final jsonString = await file.readAsString();

    // 多题库追加制：bankId 取文件内容哈希前 10 位，同一文件重复导入
    // 会命中同一个 id，天然判重；不同文件即使同名也能并存。
    report(0.08, '正在计算题库指纹');
    final fileSha256 = await _sha256File(path);
    final bankId = 'imp_${fileSha256.substring(0, 10)}';
    final support = await _support;
    final registry = BankRegistry(support.path);
    await registry.load();
    if (registry.containsId(bankId)) {
      throw const ContentImportException('这套题库已经导入过，无需重复导入');
    }

    final temporary = await _temporary;
    await support.create(recursive: true);
    final workDirectory = Directory(
      '${temporary.path}${Platform.pathSeparator}content-import',
    );
    try {
      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }
      await workDirectory.create(recursive: true);
      final databaseTemporary = File(
        '${workDirectory.path}${Platform.pathSeparator}content.sqlite',
      );

      report(0.15, '正在解析题库');
      // 解析 + 建 sqlite + 校验是纯 CPU 工作（大题库要几秒），
      // 放进独立 isolate 执行，避免导入期间整个界面卡死。
      // 注意：必须经 _parseInIsolate 中转，不能在这里直接写 Isolate.run
      // 闭包——Dart 的闭包捕获按作用域共享上下文，直接写会把
      // onProgress（ContentManager 的 ChangeNotifier，含 riverpod
      // provider 链）一起序列化，真机上报
      // "Illegal argument in isolate message: object is unsendable"。
      final summary = await _parseInIsolate(
        jsonString,
        databaseTemporary.path,
        idPrefix: bankId,
      );

      // 落盘到 banks/<bankId>/content.sqlite（原子：临时文件 rename 进
      // 正式目录）。不再替换官方题库，两套题库并存。
      report(0.9, '正在安装离线题库');
      final bankDirectory = registry.bankDirectory(bankId);
      await bankDirectory.create(recursive: true);
      final databaseStaged = File(
        '${bankDirectory.path}${Platform.pathSeparator}content.sqlite.installing',
      );
      await _deleteFileIfExists(databaseStaged);
      await databaseTemporary.rename(databaseStaged.path);
      final databaseBytes = await databaseStaged.length();
      final databaseSha256 = await _sha256File(databaseStaged.path);
      databaseStaged.renameSync(
        '${bankDirectory.path}${Platform.pathSeparator}content.sqlite',
      );
      await registry.add(
        BankInfo(
          id: bankId,
          name: summary.name,
          source: 'imported',
          contentVersion: summary.contentVersion,
          questionCount: summary.questionCount,
          paperCount: summary.paperCount,
          imageCount: summary.imageCount,
          databasePath: 'banks/$bankId/content.sqlite',
          sha256: databaseSha256,
          databaseBytes: databaseBytes,
          installedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      await _deleteSilently(workDirectory);
      report(1, '题库导入完成');
      return summary.copyWith(bankId: bankId);
    } on Object {
      // 失败时清掉工作目录、半成品和可能已建的 bank 目录（登记表只有在
      // 一切成功后才写入，所以不需要回滚）。
      await _deleteSilently(workDirectory);
      final bankDirectory = Directory(
        '${support.path}${Platform.pathSeparator}banks'
        '${Platform.pathSeparator}$bankId',
      );
      if (await bankDirectory.exists()) {
        await _deleteSilently(bankDirectory);
      }
      rethrow;
    }
  }

  static Future<void> _deleteSilently(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on Exception {
      // 清理失败不吞掉原始错误。
    }
  }

  static Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// 独立函数中转：让 Isolate.run 闭包只捕获 String 参数，
  /// 不与 importFromFile 的 onProgress/this 共享作用域上下文。
  static Future<ImportedBankSummary> _parseInIsolate(
    String jsonString,
    String databasePath, {
    String? idPrefix,
  }) {
    return Isolate.run(
      () => _parseAndBuild(jsonString, databasePath, idPrefix),
    );
  }

  /// 解析 + 建库 + 校验。在后台 isolate 里执行，只把小体积摘要带回主 isolate。
  static Future<ImportedBankSummary> _parseAndBuild(
    String jsonString,
    String databasePath,
    String? idPrefix,
  ) async {
    final bank = parseBankJson(jsonString, idPrefix: idPrefix);
    final counts = await _buildDatabase(bank, databasePath);
    return ImportedBankSummary(
      name: bank.name,
      contentVersion: bank.contentVersion,
      questionCount: counts['questionCount']!,
      paperCount: counts['paperCount']!,
      imageCount: counts['imageCount']!,
    );
  }

  static Future<String> _sha256File(String path) async {
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final input = File(path).openRead();
    await for (final chunk in input) {
      hasher.add(chunk);
    }
    hasher.close();
    return digestSink.value.toString();
  }
}

/// 解析并校验题库 JSON。所有错误都带定位（如 papers[2].questions[5]），
/// 方便作者对着大文件改错。纯函数，方便单测。
///
/// [idPrefix] 非空时给所有题目/试卷/材料组/图片 id 加 `<prefix>:` 前缀：
/// 多题库共存后全局 id 不能撞（官方库建库时已保证唯一，导入库靠这里
/// 隔离）。判重和报错文案仍用原始 id，用户看到的还是自己写的编号。
ImportedBank parseBankJson(String source, {String? idPrefix}) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw ContentImportException('题库文件不是有效的 JSON：${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ContentImportException('题库文件根节点必须是 JSON 对象');
  }
  if (decoded['format'] != _bankFormat) {
    throw const ContentImportException('题库 format 必须是 "kuangshuati-bank"');
  }
  final formatVersion = decoded['formatVersion'] ?? _bankFormatVersion;
  if (!_acceptedFormatVersions.contains(formatVersion)) {
    throw ContentImportException(
      '不支持的题库格式版本：$formatVersion（当前支持 $_acceptedFormatVersions）',
    );
  }
  final name = _optionalText(decoded['name'], 'name') ?? '自定义题库';
  final contentVersion =
      _optionalText(decoded['contentVersion'], 'contentVersion') ??
      'custom-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

  // 图片先收集：题干里 [[img:id]] 的引用要在校验题目时检查。
  final images = <String, ImportedBankImage>{};
  final rawImages = decoded['images'];
  if (rawImages != null) {
    if (rawImages is! Map<String, dynamic>) {
      throw const ContentImportException('images 必须是对象（图片ID → {mime, data}）');
    }
    rawImages.forEach((assetId, value) {
      if (assetId.trim().isEmpty) {
        throw const ContentImportException('images 里的图片 ID 不能为空');
      }
      if (value is! Map<String, dynamic>) {
        throw ContentImportException('images["$assetId"] 必须是对象');
      }
      var mime = _optionalText(value['mime'], 'images["$assetId"].mime');
      final data = _optionalText(value['data'], 'images["$assetId"].data');
      if (data == null) {
        throw ContentImportException('images["$assetId"].data 不能为空');
      }
      var payload = data.trim();
      if (payload.startsWith('data:')) {
        final separator = payload.indexOf(';base64,');
        if (separator < 0) {
          throw ContentImportException(
            'images["$assetId"].data 的 data URI 缺少 ";base64," 段',
          );
        }
        mime ??= payload.substring(5, separator);
        payload = payload.substring(separator + ';base64,'.length);
      }
      mime ??= 'image/png';
      if (!mime.startsWith('image/')) {
        throw ContentImportException(
          'images["$assetId"].mime 必须是 image/ 开头的类型（当前 $mime）',
        );
      }
      Uint8List bytes;
      try {
        bytes = base64.decode(payload.replaceAll(RegExp(r'\s'), ''));
      } on FormatException {
        throw ContentImportException('images["$assetId"].data 不是有效的 base64');
      }
      if (bytes.isEmpty) {
        throw ContentImportException('images["$assetId"].data 解码后为空');
      }
      images[prefixedId(assetId, idPrefix)] = ImportedBankImage(
        assetId: prefixedId(assetId, idPrefix),
        mime: mime,
        bytes: bytes,
      );
    });
  }

  final rawPapers = decoded['papers'];
  if (rawPapers is! List || rawPapers.isEmpty) {
    throw const ContentImportException('papers 必须是非空数组');
  }
  final papers = <ImportedBankPaper>[];
  final questionIds = <String>{};
  for (var paperIndex = 0; paperIndex < rawPapers.length; paperIndex++) {
    final rawPaper = rawPapers[paperIndex];
    final where = 'papers[$paperIndex]';
    if (rawPaper is! Map<String, dynamic>) {
      throw ContentImportException('$where 必须是对象');
    }
    final paperId = _requiredText(rawPaper['id'], '$where.id');
    if (papers.any(
      (paper) => paper.id == prefixedId(paperId, idPrefix),
    )) {
      throw ContentImportException('$where.id 与前面的试卷重复：$paperId');
    }
    final title = _requiredText(rawPaper['title'], '$where.title');
    final year =
        _optionalInt(rawPaper['year'], '$where.year', min: 0, max: 9999) ?? 0;
    final region = _optionalText(rawPaper['region'], '$where.region') ?? '未知';
    final paperType =
        _optionalText(rawPaper['paperType'], '$where.paperType') ?? '行测';
    final durationSeconds =
        _optionalInt(
          rawPaper['durationSeconds'],
          '$where.durationSeconds',
          min: 1,
          max: 24 * 3600,
        ) ??
        7200;
    final rawQuestions = rawPaper['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw ContentImportException('$where.questions 必须是非空数组');
    }
    final questions = <ImportedBankQuestion>[];
    for (
      var questionIndex = 0;
      questionIndex < rawQuestions.length;
      questionIndex++
    ) {
      final rawQuestion = rawQuestions[questionIndex];
      final at = '$where.questions[$questionIndex]';
      if (rawQuestion is! Map<String, dynamic>) {
        throw ContentImportException('$at 必须是对象');
      }
      final id = _requiredText(rawQuestion['id'], '$at.id');
      if (!questionIds.add(id)) {
        throw ContentImportException('$at.id 与其他题目重复：$id');
      }
      final module = _optionalText(rawQuestion['module'], '$at.module') ?? '综合';
      final type = _optionalText(rawQuestion['type'], '$at.type') ?? '';
      final questionNo =
          _optionalInt(rawQuestion['questionNo'], '$at.questionNo', min: 1) ??
          questionIndex + 1;
      final groupId =
          _optionalText(rawQuestion['groupId'], '$at.groupId') ?? '';
      final rawMaterial =
          _optionalText(rawQuestion['material'], '$at.material') ?? '';
      final rawStem = _requiredText(rawQuestion['stem'], '$at.stem');
      final rawSolution =
          _optionalText(rawQuestion['solution'], '$at.solution') ?? '';
      final rawOptions = rawQuestion['options'];
      final rawAnswers = rawQuestion['answer'] ?? rawQuestion['answers'];
      final optionsEmpty = rawOptions == null ||
          (rawOptions is Map<String, dynamic> && rawOptions.isEmpty);
      final answersEmpty = rawAnswers == null ||
          (rawAnswers is List && rawAnswers.isEmpty);
      // v2 自评题：options 与 answer 同时省略/为空，答题时由用户自评对错。
      // 只允许双空：一空一非空是数据错误。
      final isSelfAssessed = optionsEmpty && answersEmpty;
      final options = <String, String>{};
      final answers = <String>[];
      if (!isSelfAssessed) {
        if (optionsEmpty) {
          throw ContentImportException(
            '$at.options 必须是非空对象（如 {"A": "…"}）；'
            '如为无选项自评题，options 与 answer 需同时省略',
          );
        }
        rawOptions.forEach((key, value) {
          if (key.trim().isEmpty) {
            throw ContentImportException('$at.options 的选项键不能为空');
          }
          if (value is! String) {
            throw ContentImportException('$at.options["$key"] 必须是字符串');
          }
          options[key] = _convertImageMarkers(
            value,
            '$at.options["$key"]',
            images,
            idPrefix,
          );
        });
        if (answersEmpty) {
          throw ContentImportException(
            '$at.answer 必须是非空数组（如 ["A"]）；'
            '如为无选项自评题，options 与 answer 需同时省略',
          );
        }
        for (final key in rawAnswers) {
          if (key is! String || !options.containsKey(key)) {
            throw ContentImportException(
              '$at.answer 里的 "$key" 不在 options 的选项键 ${options.keys.toList()} 中',
            );
          }
          if (!answers.contains(key)) answers.add(key);
        }
      }
      final convertedStem = _convertImageMarkers(rawStem, '$at.stem', images, idPrefix);
      questions.add(
        ImportedBankQuestion(
          id: prefixedId(id, idPrefix),
          module: module,
          type: type,
          questionNo: questionNo,
          // 空材料组保持空串：抽题逻辑靠 group_id <> '' 识别「无组单题」。
          groupId: groupId.isEmpty ? '' : prefixedId(groupId, idPrefix),
          material: _convertImageMarkers(
            rawMaterial,
            '$at.material',
            images,
            idPrefix,
          ),
          stem: convertedStem,
          // 从转换后的题干派生（原始 [[img:]] 未替换成渲染标记）。
          stemText: _deriveStemText(rawQuestion['stemText'], convertedStem),
          options: options,
          answers: answers,
          solution: _convertImageMarkers(
            rawSolution,
            '$at.solution',
            images,
            idPrefix,
          ),
        ),
      );
    }
    papers.add(
      ImportedBankPaper(
        id: paperId,
        title: title,
        year: year,
        region: region,
        paperType: paperType,
        durationSeconds: durationSeconds,
        questions: questions,
      ),
    );
  }
  return ImportedBank(
    name: name,
    contentVersion: contentVersion,
    papers: papers,
    images: images,
  );
}

String _requiredText(Object? value, String where) {
  final text = _optionalText(value, where);
  if (text == null || text.trim().isEmpty) {
    throw ContentImportException('$where 不能为空');
  }
  return text.trim();
}

String? _optionalText(Object? value, String where) {
  if (value == null) return null;
  if (value is! String) {
    throw ContentImportException('$where 必须是字符串');
  }
  return value.trim();
}

int? _optionalInt(Object? value, String where, {int? min, int? max}) {
  if (value == null) return null;
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null) {
    throw ContentImportException('$where 必须是整数');
  }
  if (min != null && parsed < min) {
    throw ContentImportException('$where 不能小于 $min');
  }
  if (max != null && parsed > max) {
    throw ContentImportException('$where 不能大于 $max');
  }
  return parsed;
}

/// 多题库 id 前缀：导入库的所有 id 统一加 `<bankId>:` 保证跨库唯一。
String prefixedId(String id, String? prefix) =>
    prefix == null || prefix.isEmpty ? id : '$prefix:$id';

/// `[[img:ID]]` → 官方渲染管线认识的 \ue000ID\ue001，并检查 ID 已定义。
/// [idPrefix] 与 parseBankJson 一致：images 的 key 已带前缀，这里查找与
/// 输出同步加前缀，markup 里的引用就指向合成后的 assetId。
String _convertImageMarkers(
  String text,
  String where,
  Map<String, ImportedBankImage> images,
  String? idPrefix,
) {
  if (!text.contains('[[')) return text;
  return text.replaceAllMapped(RegExp(r'\[\[\s*img\s*:\s*([^\]]+?)\s*\]\]'), (
    match,
  ) {
    final assetId = match.group(1)!;
    final resolved = prefixedId(assetId, idPrefix);
    if (!images.containsKey(resolved)) {
      throw ContentImportException(
        '$where 引用了未定义的图片 "$assetId"（请在顶层 images 里补充）',
      );
    }
    return '$imageMarkerOpen$resolved$imageMarkerClose';
  });
}

/// 检索用纯文本：优先用户给的 stemText，否则从题干去掉图片标记生成。
/// 两种形式都兼容：渲染标记 \ue000…\ue001 和原始 [[img:…]]。
String _deriveStemText(Object? provided, String convertedStem) {
  final source = provided is String && provided.trim().isNotEmpty
      ? provided
      : convertedStem;
  return source
      .replaceAll(
        RegExp('$imageMarkerOpen[^$imageMarkerClose]*$imageMarkerClose'),
        '',
      )
      .replaceAll(RegExp(r'\[\[\s*img\s*:[^\]]*\]\]'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// 建库：表结构与官方建库脚本 tools/import_question_bank.py 的 SCHEMA 一致
/// （除 raw_solutions——官方装包前也会删掉它）。完成后做完整性与大小校验。
Future<Map<String, int>> _buildDatabase(
  ImportedBank bank,
  String databasePath,
) async {
  final database = sqlite3.open(databasePath);
  try {
    database.execute('PRAGMA page_size = 4096');
    database.execute('PRAGMA journal_mode = OFF');
    database.execute('PRAGMA synchronous = OFF');
    database.execute('PRAGMA temp_store = MEMORY');
    database.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE TABLE papers (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        year INTEGER NOT NULL,
        region TEXT NOT NULL,
        paper_type TEXT NOT NULL,
        module TEXT NOT NULL,
        question_count INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL
      );
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        paper_id TEXT NOT NULL,
        paper_title TEXT NOT NULL,
        year INTEGER NOT NULL,
        region TEXT NOT NULL,
        module TEXT NOT NULL,
        question_no INTEGER NOT NULL,
        sequence INTEGER NOT NULL,
        question_type TEXT NOT NULL,
        group_id TEXT NOT NULL,
        group_number INTEGER,
        stem_markup TEXT NOT NULL,
        stem_text TEXT NOT NULL,
        options_json TEXT NOT NULL,
        correct_json TEXT NOT NULL,
        solution_markup TEXT NOT NULL,
        material_markup TEXT NOT NULL,
        content_hash TEXT NOT NULL
      );
      CREATE TABLE assets (
        asset_id TEXT PRIMARY KEY,
        hash TEXT NOT NULL,
        mime TEXT NOT NULL,
        width INTEGER,
        height INTEGER,
        available INTEGER NOT NULL DEFAULT 0
      );
      CREATE TABLE images (
        hash TEXT PRIMARY KEY,
        mime TEXT NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        data BLOB NOT NULL
      );
      CREATE INDEX questions_paper_sequence
        ON questions(paper_id, sequence, question_no);
      CREATE INDEX questions_module
        ON questions(module, year, paper_id);
      CREATE INDEX questions_year
        ON questions(year, sequence);
      CREATE INDEX papers_year_region
        ON papers(year DESC, region, title);
    ''');

    // 图片按内容哈希去重（多张相同 data 只存一份字节）。
    final imageHashes = <String, ({int width, int height})>{};
    if (bank.images.isNotEmpty) {
      final imageStatement = database.prepare(
        'INSERT OR REPLACE INTO images(hash, mime, width, height, data) '
        'VALUES (?, ?, ?, ?, ?)',
      );
      final assetStatement = database.prepare(
        'INSERT OR REPLACE INTO assets(asset_id, hash, mime, width, height, available) '
        'VALUES (?, ?, ?, ?, ?, ?)',
      );
      try {
        for (final image in bank.images.values) {
          final hash = sha256.convert(image.bytes).toString();
          final size = _sniffImageSize(image.bytes);
          // 同一份字节只在 images 表落一次；尺寸嗅探失败的图片不进
          // images 表（height NOT NULL），资产标记不可用，渲染层
          // 自然回退到无图。
          if (size != null && !imageHashes.containsKey(hash)) {
            imageStatement.execute([
              hash,
              image.mime,
              size.width,
              size.height,
              image.bytes,
            ]);
            imageHashes[hash] = (width: size.width, height: size.height);
          }
          final known = imageHashes[hash];
          assetStatement.execute([
            image.assetId,
            hash,
            image.mime,
            known?.width,
            known?.height,
            known != null ? 1 : 0,
          ]);
        }
      } finally {
        imageStatement.close();
        assetStatement.close();
      }
    }

    var questionCount = 0;
    final questionStatement = database.prepare('''
      INSERT INTO questions(
        id, paper_id, paper_title, year, region, module, question_no,
        sequence, question_type, group_id, group_number, stem_markup,
        stem_text, options_json, correct_json, solution_markup,
        material_markup, content_hash
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    final paperStatement = database.prepare('''
      INSERT INTO papers(
        id, title, year, region, paper_type, module, question_count,
        duration_seconds
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      for (final paper in bank.papers) {
        for (var index = 0; index < paper.questions.length; index++) {
          final question = paper.questions[index];
          final optionsJson = jsonEncode(question.options);
          final correctJson = jsonEncode(question.answers);
          final contentHash = sha256
              .convert(
                utf8.encode(
                  '${question.id}|${question.stem}|$optionsJson|$correctJson',
                ),
              )
              .toString();
          questionStatement.execute([
            question.id,
            paper.id,
            paper.title,
            paper.year,
            paper.region,
            question.module,
            question.questionNo,
            index + 1,
            question.type,
            question.groupId,
            null,
            question.stem,
            question.stemText,
            optionsJson,
            correctJson,
            question.solution,
            question.material,
            contentHash,
          ]);
          questionCount++;
        }
        paperStatement.execute([
          paper.id,
          paper.title,
          paper.year,
          paper.region,
          paper.paperType,
          '综合',
          paper.questions.length,
          paper.durationSeconds,
        ]);
      }
    } finally {
      questionStatement.close();
      paperStatement.close();
    }

    final metadataRows = <(String, String)>[
      ('schema_version', '1'),
      ('content_version', bank.contentVersion),
      ('question_count', '$questionCount'),
      ('paper_count', '${bank.papers.length}'),
      ('image_count', '${imageHashes.length}'),
      ('bank_name', bank.name),
    ];
    database.execute('BEGIN');
    final metadataStatement = database.prepare(
      'INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)',
    );
    try {
      for (final (key, value) in metadataRows) {
        metadataStatement.execute([key, value]);
      }
    } finally {
      metadataStatement.close();
    }
    database.execute('COMMIT');
    database.execute('VACUUM');
    final integrity = database
        .select('PRAGMA integrity_check')
        .first
        .columnAt(0);
    if (integrity != 'ok') {
      throw ContentImportException('题库数据库完整性检查失败：$integrity');
    }
    return {
      'questionCount': questionCount,
      'paperCount': bank.papers.length,
      'imageCount': imageHashes.length,
    };
  } on SqliteException catch (error) {
    throw ContentImportException('写入题库数据库失败：${error.message}');
  } finally {
    database.close();
  }
}

({int width, int height})? _sniffImageSize(Uint8List bytes) {
  if (bytes.length >= 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    // PNG：IHDR 宽高在固定偏移，大端。
    return (width: _bigEndian(bytes, 16), height: _bigEndian(bytes, 20));
  }
  if (bytes.length >= 10 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    // GIF87a/89a：小端 u16。
    return (
      width: bytes[6] | (bytes[7] << 8),
      height: bytes[8] | (bytes[9] << 8),
    );
  }
  if (bytes.length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    // JPEG：扫 SOFn 段。
    var position = 2;
    while (position + 9 <= bytes.length) {
      if (bytes[position] != 0xFF) {
        position++;
        continue;
      }
      final marker = bytes[position + 1];
      if (marker == 0xD8 ||
          marker == 0x01 ||
          (marker >= 0xD0 && marker <= 0xD7)) {
        position += 2;
        continue;
      }
      if (marker == 0xDA || marker == 0xD9) {
        return null; // 扫到数据/文件尾还没遇到 SOF。
      }
      const sofMarkers = {
        0xC0,
        0xC1,
        0xC2,
        0xC3,
        0xC5,
        0xC6,
        0xC7,
        0xC9,
        0xCA,
        0xCB,
        0xCD,
        0xCE,
        0xCF,
      };
      if (sofMarkers.contains(marker)) {
        return (
          width: _bigEndian(bytes, position + 7),
          height: _bigEndian(bytes, position + 5),
        );
      }
      final length = _bigEndian(bytes, position + 2);
      if (length < 2) return null;
      position += 2 + length;
    }
    return null;
  }
  if (bytes.length >= 30 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    // WebP：VP8X / VP8 / VP8L 三种子格式。
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    if (chunk == 'VP8X') {
      return (
        width: _littleEndian24(bytes, 24) + 1,
        height: _littleEndian24(bytes, 27) + 1,
      );
    }
    if (chunk == 'VP8 ' &&
        bytes.length >= 30 &&
        bytes[23] == 0x9D &&
        bytes[24] == 0x01 &&
        bytes[25] == 0x2A) {
      return (
        width: (bytes[26] | (bytes[27] << 8)) & 0x3FFF,
        height: (bytes[28] | (bytes[29] << 8)) & 0x3FFF,
      );
    }
    if (chunk == 'VP8L' && bytes.length >= 25 && bytes[20] == 0x2F) {
      final bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      return (width: (bits & 0x3FFF) + 1, height: ((bits >> 14) & 0x3FFF) + 1);
    }
  }
  return null;
}

int _bigEndian(Uint8List bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

int _littleEndian24(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
