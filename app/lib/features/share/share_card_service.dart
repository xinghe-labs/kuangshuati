import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// 分享成绩卡的渲染与落盘（share_plus 的调用在页面层）。
///
/// 卡片固定用浅色版式：分享出去的图不随系统深色模式变化，
/// 白底黑字在微信/朋友圈等白底场景里也更干净。
class ShareCardData {
  const ShareCardData({
    required this.answered,
    required this.correct,
    required this.streakDays,
    required this.totalDays,
    required this.dateLabel,
  });

  final int answered;
  final int correct;
  final int streakDays;
  final int totalDays;

  /// 卡片右上角展示的日期，如「2026-11-07」。
  final String dateLabel;

  /// 正确率整数（0-100）；没有作答记录时为 null，卡片显示「—」。
  int? get accuracyPercent =>
      answered == 0 ? null : (correct * 100 / answered).round();
}

/// 卡片宽度（4:5，社交平台友好比例）。
const int kShareCardWidth = 1080;
const int kShareCardHeight = 1350;

const _paper = Color(0xFFF4F3EF);
const _surface = Color(0xFFFCFBF8);
const _ink = Color(0xFF171715);
const _muted = Color(0xFF74746E);
const _line = Color(0xFFD9D8D1);

/// 渲染成绩卡并写入临时目录，返回文件路径；渲染失败返回 null。
Future<File?> renderShareCard(ShareCardData data) async {
  try {
    final image = await _paint(data);
    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    // toByteData 在极少数机型上可能返回 null，别让分享入口因此崩溃。
    if (byteData == null) return null;
    image.dispose();

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}share_card_${data.dateLabel}.png',
    );
    return file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  } on Object {
    return null;
  }
}

Future<ui.Image> _paint(ShareCardData data) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(kShareCardWidth.toDouble(), kShareCardHeight.toDouble());

  canvas.drawRect(Offset.zero & size, Paint()..color = _paper);

  // 品牌行：左「狂刷题」，右日期。
  _text(
    canvas,
    '狂刷题',
    const Offset(72, 96),
    fontSize: 76,
    fontWeight: FontWeight.w800,
    color: _ink,
  );
  _text(
    canvas,
    data.dateLabel,
    Offset(kShareCardWidth - 72, 128),
    fontSize: 36,
    color: _muted,
    align: TextAlign.right,
  );
  _hairline(canvas, 224);

  // 指标区：三列大数字（近 7 天答题 / 正确率 / 连续练习）。
  const metrics = <(String, String, String)>[
    ('近 7 天', '题', '已答'),
    ('正确率', '%', '正确'),
    ('连续练习', '天', '坚持'),
  ];
  final values = [
    '${data.answered}',
    data.accuracyPercent == null ? '—' : '${data.accuracyPercent}',
    '${data.streakDays}',
  ];
  _text(
    canvas,
    '最近 7 天成绩',
    const Offset(72, 300),
    fontSize: 40,
    color: _muted,
  );
  final columnWidth = (kShareCardWidth - 144) / 3;
  for (var i = 0; i < 3; i++) {
    final x = 72 + columnWidth * i;
    _text(
      canvas,
      values[i],
      Offset(x, 424),
      fontSize: 128,
      fontWeight: FontWeight.w800,
      color: _ink,
    );
    _text(
      canvas,
      '${metrics[i].$1}（${metrics[i].$2}）',
      Offset(x, 600),
      fontSize: 38,
      color: _muted,
    );
  }
  _hairline(canvas, 760);

  // 底部黑色口号卡：与首页「今天继续把题刷透」同一视觉语言。
  const cardRect = Rect.fromLTWH(72, 840, kShareCardWidth - 144, 360);
  canvas.drawRRect(
    RRect.fromRectAndRadius(cardRect, const Radius.circular(16)),
    Paint()..color = _ink,
  );
  _text(
    canvas,
    '把行测真题刷透',
    const Offset(120, 940),
    fontSize: 64,
    fontWeight: FontWeight.w800,
    color: _surface,
  );
  _text(
    canvas,
    '断网可用 · 不用注册 · 记录只留在这台设备上',
    const Offset(120, 1060),
    fontSize: 36,
    color: const Color(0xFFBDBDB7),
  );

  _text(
    canvas,
    '来自「狂刷题」App',
    Offset(kShareCardWidth - 72, kShareCardHeight - 96),
    fontSize: 32,
    color: _muted,
    align: TextAlign.right,
  );

  final picture = recorder.endRecording();
  return picture.toImage(kShareCardWidth, kShareCardHeight);
}

void _hairline(Canvas canvas, double y) {
  canvas.drawLine(
    Offset(72, y),
    Offset(kShareCardWidth - 72, y),
    Paint()
      ..color = _line
      ..strokeWidth = 2,
  );
}

void _text(
  Canvas canvas,
  String text,
  Offset offset, {
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  required Color color,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.2,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: kShareCardWidth - 144);
  // 右对齐时以 offset 为右缘，其余以 offset 为左缘。
  final dx = align == TextAlign.right ? offset.dx - painter.width : offset.dx;
  painter.paint(canvas, Offset(dx, offset.dy));
}

/// Uint8List 便于测试里直接断言 PNG 头。
Uint8List? pngSignatureOf(File? file) {
  if (file == null || !file.existsSync()) return null;
  final bytes = file.readAsBytesSync();
  if (bytes.length < 8) return null;
  return bytes.sublist(0, 8);
}
