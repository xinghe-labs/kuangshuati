import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/content/content_repository.dart';

/// 题库的「安装 / 更新」状态。
enum ContentManagerPhase { checking, needsDownload, downloading, ready, failed }

/// 题库安装/更新的统一接口。
///
/// 移动端和 Web 端的题库来源完全不同：移动端下载一个 297 MiB 的 SQLite 包
/// 落到应用目录，Web 端把题目核心库灌进浏览器的 OPFS/IndexedDB、图片按需
/// 拉取。但页面对这两者要的东西是一样的——当前能不能用、进度多少、
/// 出错没有、当前仓库对象是谁。
///
/// 所以这里只约定这些共同点，具体怎么下载由各平台实现。
abstract class ContentManagerBase extends ChangeNotifier {
  ContentRepository get repository;
  ContentManagerPhase get phase;
  double get progress;
  String get stage;
  String? get errorMessage;
  bool get hasFullContent;

  /// 底层异常原文，只在调试构建里展示。
  String? get errorDetail;

  /// 是否已拿到远端清单（拿到了才能下载）。
  bool get hasManifest;

  /// 远端是否有比本地新的题库版本。
  bool get updateAvailable;

  /// 检查远端清单。未安装题库时也用它拿下载地址。
  Future<void> checkForManifest();

  /// 下载并安装/更新题库。
  Future<void> downloadAndInstall();

  /// 仅在用户主动点「检查更新」时调用。
  Future<void> refresh();
}
