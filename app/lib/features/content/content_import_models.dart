import 'dart:typed_data';

/// 题库导入的纯数据类型（异常 + 数据模型）。
///
/// 单独成文件的原因：web 构建编不到 `dart:ffi`，而 [ContentImportService]
/// 的实现要用 `package:sqlite3`（FFI 版）。设置页/基类只需要这些类型，
/// 不需要实现；实现与类型分库后，web 图才不会被 sqlite3 拖垮。

/// 题干/选项/材料/解析里内嵌图片的标记，与官方建库管线
/// （tools/import_question_bank.py 的 IMAGE_OPEN/CLOSE）保持一致。
const imageMarkerOpen = '\ue000';
const imageMarkerClose = '\ue001';

class ContentImportException implements Exception {
  const ContentImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 一道已通过校验、可直接入库的题目。
class ImportedBankQuestion {
  ImportedBankQuestion({
    required this.id,
    required this.module,
    required this.type,
    required this.questionNo,
    required this.groupId,
    required this.material,
    required this.stem,
    required this.stemText,
    required this.options,
    required this.answers,
    required this.solution,
  });

  final String id;
  final String module;
  final String type;
  final int questionNo;
  final String groupId;
  final String material;
  final String stem;
  final String stemText;
  final Map<String, String> options;
  final List<String> answers;
  final String solution;
}

class ImportedBankPaper {
  ImportedBankPaper({
    required this.id,
    required this.title,
    required this.year,
    required this.region,
    required this.paperType,
    required this.durationSeconds,
    required this.questions,
  });

  final String id;
  final String title;
  final int year;
  final String region;
  final String paperType;
  final int durationSeconds;
  final List<ImportedBankQuestion> questions;
}

class ImportedBankImage {
  ImportedBankImage({
    required this.assetId,
    required this.mime,
    required this.bytes,
  });

  final String assetId;
  final String mime;
  final Uint8List bytes;
}

class ImportedBank {
  ImportedBank({
    required this.name,
    required this.contentVersion,
    required this.papers,
    required this.images,
  });

  final String name;
  final String contentVersion;
  final List<ImportedBankPaper> papers;
  final Map<String, ImportedBankImage> images;
}

/// 导入完成后的结果摘要。
class ImportedBankSummary {
  const ImportedBankSummary({
    required this.name,
    required this.contentVersion,
    required this.questionCount,
    required this.paperCount,
    required this.imageCount,
    this.bankId,
  });

  final String name;
  final String contentVersion;
  final int questionCount;
  final int paperCount;
  final int imageCount;

  /// 多题库追加制：本次导入登记的 bankId（追加进题库列表后可用）。
  final String? bankId;

  ImportedBankSummary copyWith({String? bankId}) => ImportedBankSummary(
    name: name,
    contentVersion: contentVersion,
    questionCount: questionCount,
    paperCount: paperCount,
    imageCount: imageCount,
    bankId: bankId ?? this.bankId,
  );
}
