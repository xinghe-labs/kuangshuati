import 'dart:convert';
import 'dart:io';

/// 一套已安装题库的元信息。
///
/// 多题库共存：官方下载的题库和用户导入的自制题库都以独立 sqlite 文件
/// 并存（`banks/<id>/content.sqlite` 或迁移过来的旧版单文件），
/// 由 [BankRegistry] 统一登记。查询层把所有库 ATTACH 后用视图合并。
class BankInfo {
  const BankInfo({
    required this.id,
    required this.name,
    required this.source,
    required this.contentVersion,
    required this.questionCount,
    required this.paperCount,
    required this.imageCount,
    required this.databasePath,
    this.sha256,
    this.installedAt,
    this.databaseBytes,
  });

  BankInfo.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String? ?? '题库',
      source = json['source'] as String? ?? 'imported',
      contentVersion = json['contentVersion'] as String? ?? 'unknown',
      questionCount = (json['questionCount'] as num?)?.toInt() ?? 0,
      paperCount = (json['paperCount'] as num?)?.toInt() ?? 0,
      imageCount = (json['imageCount'] as num?)?.toInt() ?? 0,
      databasePath = json['databasePath'] as String,
      sha256 = json['sha256'] as String?,
      installedAt = json['installedAt'] as String?,
      databaseBytes = (json['databaseBytes'] as num?)?.toInt();

  /// 官方题库固定 id；导入库 id 为 `imp_<sha256 前 10 位>`，
  /// 同一文件重复导入会命中同一 id，天然判重。
  static const officialId = 'official';

  final String id;

  /// 展示名（题库管理页 / 统计页）。
  final String name;

  /// `official`（下载安装）或 `imported`（本地 JSON 导入）。
  final String source;
  final String contentVersion;
  final int questionCount;
  final int paperCount;
  final int imageCount;

  /// 相对 support 目录的 sqlite 文件路径（旧安装迁移后仍是根目录下的
  /// `content.sqlite`，新装在 `banks/<id>/content.sqlite`）。
  final String databasePath;
  final String? sha256;
  final String? installedAt;

  /// sqlite 文件字节数（题库管理页显示占用大小）。
  final int? databaseBytes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'contentVersion': contentVersion,
    'questionCount': questionCount,
    'paperCount': paperCount,
    'imageCount': imageCount,
    'databasePath': databasePath,
    if (sha256 != null) 'sha256': sha256,
    if (installedAt != null) 'installedAt': installedAt,
    if (databaseBytes != null) 'databaseBytes': databaseBytes,
  };

  BankInfo copyWith({
    String? name,
    String? contentVersion,
    int? questionCount,
    int? paperCount,
    int? imageCount,
    String? sha256,
    int? databaseBytes,
  }) => BankInfo(
    id: id,
    name: name ?? this.name,
    source: source,
    contentVersion: contentVersion ?? this.contentVersion,
    questionCount: questionCount ?? this.questionCount,
    paperCount: paperCount ?? this.paperCount,
    imageCount: imageCount ?? this.imageCount,
    databasePath: databasePath,
    sha256: sha256 ?? this.sha256,
    installedAt: installedAt,
    databaseBytes: databaseBytes ?? this.databaseBytes,
  );
}

/// 已安装题库登记表（`<support>/banks.json`）。
///
/// 负责三件事：
/// 1. 读写登记表（原子落盘：写临时文件再 rename）；
/// 2. 旧版单文件安装的自动迁移——首次遇到没有 banks.json 但存在
///    `content.sqlite` 的安装时，把旧文件登记为官方题库（不移动文件）；
/// 3. 题库文件绝对路径换算。
class BankRegistry {
  BankRegistry(this.supportPath);

  final String supportPath;

  final List<BankInfo> banks = [];

  File get _registryFile => File(
    '$supportPath${Platform.pathSeparator}banks.json',
  );

  File get _legacyDatabaseFile => File(
    '$supportPath${Platform.pathSeparator}content.sqlite',
  );

  File get _legacyManifestFile => File(
    '$supportPath${Platform.pathSeparator}content-installed.json',
  );

  Future<void> load() async {
    banks.clear();
    final file = _registryFile;
    if (await file.exists()) {
      try {
        final decoded =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final item in (decoded['banks'] as List? ?? const [])) {
          banks.add(BankInfo.fromJson(item as Map<String, dynamic>));
        }
      } on FormatException {
        // 登记表损坏按「无登记」处理，走下面的旧安装迁移兜底。
      }
    }
    final migrated = await _migrateLegacyInstallIfNeeded();
    if (migrated) await save();
  }

  /// 旧版单文件安装 → 登记为官方题库。文件原地不动。
  Future<bool> _migrateLegacyInstallIfNeeded() async {
    if (banks.any((bank) => bank.id == BankInfo.officialId)) return false;
    if (!await _legacyDatabaseFile.exists()) return false;
    if (!await _legacyManifestFile.exists()) return false;
    try {
      final manifest =
          jsonDecode(await _legacyManifestFile.readAsString())
              as Map<String, dynamic>;
      banks.add(
        BankInfo(
          id: BankInfo.officialId,
          name: manifest['bankName'] as String? ?? '行测真题',
          source: 'official',
          contentVersion:
              manifest['contentVersion']?.toString() ?? 'unknown',
          questionCount: (manifest['questionCount'] as num?)?.toInt() ?? 0,
          paperCount: (manifest['paperCount'] as num?)?.toInt() ?? 0,
          imageCount: (manifest['imageCount'] as num?)?.toInt() ?? 0,
          databasePath: 'content.sqlite',
          sha256: manifest['databaseSha256'] as String?,
          databaseBytes: (manifest['databaseBytes'] as num?)?.toInt(),
        ),
      );
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> save() async {
    final staged = File('${_registryFile.path}.staging');
    await staged.writeAsString(
      jsonEncode({
        'version': 1,
        'banks': [for (final bank in banks) bank.toJson()],
      }),
      flush: true,
    );
    await staged.rename(_registryFile.path);
  }

  BankInfo? byId(String id) {
    for (final bank in banks) {
      if (bank.id == id) return bank;
    }
    return null;
  }

  bool containsId(String id) => byId(id) != null;

  /// 导入判重：同一文件（相同 sha256）不允许重复导入。
  bool containsSha256(String sha256) =>
      banks.any((bank) => bank.sha256 == sha256);

  Future<void> add(BankInfo bank) async {
    banks.removeWhere((existing) => existing.id == bank.id);
    banks.add(bank);
    await save();
  }

  /// 移除登记（不删文件，文件由调用方处理）。
  Future<void> remove(String id) async {
    banks.removeWhere((bank) => bank.id == id);
    await save();
  }

  String absoluteDatabasePath(BankInfo bank) =>
      '$supportPath${Platform.pathSeparator}'
      '${bank.databasePath.replaceAll('/', Platform.pathSeparator)}';

  /// 新导入题库的落盘目录（`banks/<id>/`）。
  Directory bankDirectory(String id) => Directory(
    '$supportPath${Platform.pathSeparator}banks'
    '${Platform.pathSeparator}$id',
  );

  int get totalQuestionCount =>
      banks.fold(0, (sum, bank) => sum + bank.questionCount);

  int get totalPaperCount =>
      banks.fold(0, (sum, bank) => sum + bank.paperCount);
}
