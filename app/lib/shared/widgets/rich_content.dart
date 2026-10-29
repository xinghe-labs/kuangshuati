import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/content/content_repository.dart' as repo;

/// 行内/块级分流阈值（逻辑像素）。
/// - 图高 ≤ [_kInlineImageMaxHeight]：行内，与文字同基线混排，按字号缩放。
/// - 夹在句中（前后同一行都有文字）且图高 ≤ [_kInlineImageContextMaxHeight]：
///   也算行内——双行公式、带上下标的公式图高 41–60，只按阈值会被误判成块级。
/// - 图高 > [_kBlockImageMaxHeight]：块级居中，最大高度放宽到 380。
/// - 其余：块级左对齐，无灰底，点击放大。
const _kInlineImageMaxHeight = 40.0;

/// 句中图行内上限：约 2.6 倍行高，再高会把整段行距搅乱，仍按块级。
const _kInlineImageContextMaxHeight = 72.0;
const _kBlockImageMaxHeight = 200.0;

/// 行内图缩放基准：公式图设计高度 28px 对应 fontSize 15。
const _kInlineDesignFontSize = 15.0;

/// 题图富文本：分段落渲染；行内小图与文字同基线混排，
/// 连续块级图用 Wrap 并排；所有图保留点击放大。
class RichContent extends ConsumerWidget {
  const RichContent(this.markup, {this.style, super.key});

  final String markup;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseStyle =
        style ??
        const TextStyle(color: AppColors.ink, fontSize: 15, height: 1.65);
    final segments = _parseSegments(markup);
    // markup 里的 PUA 图标记不带尺寸，从资产索引同步查高度（仅当前题的几张图）。
    final heights = ref
        .read(contentRepositoryProvider)
        .imageHeightsSync(
          segments
              .where((segment) => segment.assetId != null)
              .map((segment) => segment.assetId!),
        );
    // 行内判定：阈值内，或夹在句中（前后同一行都有文字）且高度不超句中上限。
    final inlineFlags = _resolveInlineFlags(segments, heights);

    // 文字与行内图必须同处一个 TextSpan 流，否则每张公式图都会独占一行。
    final paragraphs = <Widget>[];
    final inlineSpans = <InlineSpan>[];
    final blockImages = <_Segment>[];

    void flushInline() {
      if (inlineSpans.isEmpty) return;
      paragraphs.add(
        SelectableText.rich(
          TextSpan(children: List.of(inlineSpans), style: baseStyle),
        ),
      );
      inlineSpans.clear();
    }

    void flushImages() {
      if (blockImages.isEmpty) return;
      paragraphs.add(
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final image in blockImages)
              _BlockAssetImage(assetId: image.assetId!),
          ],
        ),
      );
      blockImages.clear();
    }

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.assetId == null) {
        flushImages();
        // 段内单换行保留为换行，空行切成新段落并保留段落间距。
        final parts = segment.text.split(RegExp(r'\n{2,}'));
        for (var partIndex = 0; partIndex < parts.length; partIndex++) {
          if (partIndex > 0) flushInline();
          final part = parts[partIndex].trim();
          if (part.isEmpty) continue;
          // 不插空格：原 markup 中 PUA 标记就紧贴中文，公式需与文字相连。
          inlineSpans.add(TextSpan(text: part));
        }
        continue;
      }
      final knownHeight = heights[segment.assetId] ?? segment.height;
      if (inlineFlags[index]) {
        flushImages();
        // 行内图：去灰底、去全宽，按字号缩放与文字同基线。
        final scale = baseStyle.fontSize != null
            ? baseStyle.fontSize! / _kInlineDesignFontSize
            : 1.0;
        final inlineHeight = (knownHeight ?? _kInlineDesignFontSize) * scale;
        inlineSpans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            baseline: TextBaseline.ideographic,
            child: _InlineAssetImage(
              assetId: segment.assetId!,
              targetHeight: inlineHeight,
            ),
          ),
        );
        continue;
      }
      // 块级图（含未知尺寸，先按块级展示，加载后再按实际高度重判）。
      flushInline();
      blockImages.add(segment);
    }
    flushInline();
    flushImages();

    if (paragraphs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          paragraphs[index],
        ],
      ],
    );
  }
}

/// 逐张图判定行内还是块级。
/// 只靠高度阈值不够：多行公式、带上下标的公式图高 41–60，在原文里是句中成分，
/// 单独成行会把句子切断。所以再给一条“夹在句中”的豁免。
List<bool> _resolveInlineFlags(
  List<_Segment> segments,
  Map<String, int> heights,
) {
  bool hasTextBefore(int index) {
    if (index == 0) return false;
    final previous = segments[index - 1];
    if (previous.assetId != null) return false;
    if (previous.text.trim().isEmpty) return false;
    return !previous.text.endsWith('\n');
  }

  bool hasTextAfter(int index) {
    if (index == segments.length - 1) return false;
    final next = segments[index + 1];
    if (next.assetId != null) return false;
    if (next.text.trim().isEmpty) return false;
    return !next.text.startsWith('\n');
  }

  final flags = List<bool>.filled(segments.length, false);
  for (var index = 0; index < segments.length; index++) {
    final assetId = segments[index].assetId;
    if (assetId == null) continue;
    final height = heights[assetId] ?? segments[index].height;
    if (height == null || height <= 0) continue;
    if (height <= _kInlineImageMaxHeight) {
      flags[index] = true;
      continue;
    }
    flags[index] =
        height <= _kInlineImageContextMaxHeight &&
        hasTextBefore(index) &&
        hasTextAfter(index);
  }
  return flags;
}

/// 行内小图：无灰底、按目标高度等比缩放，点击放大。
class _InlineAssetImage extends ConsumerStatefulWidget {
  const _InlineAssetImage({required this.assetId, required this.targetHeight});

  final String assetId;
  final double targetHeight;

  @override
  ConsumerState<_InlineAssetImage> createState() => _InlineAssetImageState();
}

class _InlineAssetImageState extends ConsumerState<_InlineAssetImage> {
  Future<repo.ContentImage?>? _future;
  String? _loadedAssetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _InlineAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _loadedAssetId = null;
      _ensureFuture();
    }
  }

  void _ensureFuture() {
    if (_loadedAssetId == widget.assetId) return;
    _loadedAssetId = widget.assetId;
    final repository = ref.read(contentRepositoryProvider);
    _future = Future.sync(() => repository.imageWithSize(widget.assetId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<repo.ContentImage?>(
      future: _future,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null || image.bytes.isEmpty) {
          // 行内占位：等高空白，缺失提示交给块级视图，不打断文字流。
          return SizedBox(
            height: widget.targetHeight,
            width: widget.targetHeight * 1.4,
          );
        }
        final ratio = image.width / image.height;
        final imageWidget = Image.memory(
          image.bytes,
          height: widget.targetHeight,
          width: widget.targetHeight * ratio,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
        return Semantics(
          button: true,
          label: '查看题图',
          child: GestureDetector(
            onTap: () => _showImage(context, image.bytes),
            child: imageWidget,
          ),
        );
      },
    );
  }
}

/// 块级图：无灰底全宽灰条，未知尺寸先按块级展示；>200px 居中，
/// 最大高度 380；点击放大。
class _BlockAssetImage extends ConsumerStatefulWidget {
  const _BlockAssetImage({required this.assetId});

  final String assetId;

  @override
  ConsumerState<_BlockAssetImage> createState() => _BlockAssetImageState();
}

class _BlockAssetImageState extends ConsumerState<_BlockAssetImage> {
  Future<repo.ContentImage?>? _future;
  String? _loadedAssetId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureFuture();
  }

  @override
  void didUpdateWidget(covariant _BlockAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      _loadedAssetId = null;
      _ensureFuture();
    }
  }

  void _ensureFuture() {
    if (_loadedAssetId == widget.assetId) return;
    _loadedAssetId = widget.assetId;
    final repository = ref.read(contentRepositoryProvider);
    _future = Future.sync(() => repository.imageWithSize(widget.assetId));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<repo.ContentImage?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: 160,
            height: 72,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final image = snapshot.data;
        if (image == null || image.bytes.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: AppColors.softFill,
            child: const Text(
              '图片缺失',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          );
        }
        final isLarge = image.height > _kBlockImageMaxHeight;
        final imageWidget = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: Image.memory(
            image.bytes,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const Text(
              '图片无法显示',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        );
        return Semantics(
          button: true,
          label: '查看题图',
          child: GestureDetector(
            onTap: () => _showImage(context, image.bytes),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: isLarge
                  ? Center(child: imageWidget)
                  : Align(alignment: Alignment.centerLeft, child: imageWidget),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _showImage(BuildContext context, Uint8List bytes) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: AppColors.ink,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 5,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Segment {
  const _Segment.text(this.text) : assetId = null, height = null;
  const _Segment.image(this.assetId, this.height) : text = '';

  final String text;
  final String? assetId;
  final int? height;
}

List<_Segment> _parseSegments(String input) {
  final segments = <_Segment>[];
  final markup = input.replaceAllMapped(
    RegExp('([^]+)'),
    (match) => '<img src="asset://${match.group(1)}">',
  );
  final imagePattern = RegExp(
    r'''<img\b([^>]*)\bsrc\s*=\s*(["'])asset://([^"']+)\2([^>]*)>''',
    caseSensitive: false,
  );
  var cursor = 0;
  for (final match in imagePattern.allMatches(markup)) {
    final text = _plainText(markup.substring(cursor, match.start));
    if (text.isNotEmpty) segments.add(_Segment.text(text));
    final attributes = '${match.group(1)!} ${match.group(4)!}';
    segments.add(_Segment.image(match.group(3)!, _parseHeight(attributes)));
    cursor = match.end;
  }
  final tail = _plainText(markup.substring(cursor));
  if (tail.isNotEmpty) segments.add(_Segment.text(tail));
  if (segments.isEmpty) segments.add(_Segment.text(_plainText(markup)));
  return segments;
}

/// 从 <img> 属性串解析声明的像素高度，供行内/块级分流。
int? _parseHeight(String attributes) {
  final heightPattern = RegExp(
    r'''\bheight\s*[:=]\s*["']?\s*(\d+)''',
    caseSensitive: false,
  );
  final match = heightPattern.firstMatch(attributes);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

String _plainText(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(?:p|div|li|tr|h[1-6])>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<u>\s*</u>', caseSensitive: false), '________')
      .replaceAll(RegExp(r'</?u>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
