import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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
class RichContent extends ConsumerStatefulWidget {
  const RichContent(this.markup, {this.style, this.selectable = true, super.key});

  final String markup;
  final TextStyle? style;

  /// 是否允许长按选字。
  ///
  /// `SelectableText` 自带的手势识别会呑掉外层 InkWell 的点击，
  /// 所以放进「整块可点」区域的文字（选项）必须关掉，
  /// 否则用户点选项文字没有任何反应。
  final bool selectable;

  @override
  ConsumerState<RichContent> createState() => _RichContentState();
}

class _RichContentState extends ConsumerState<RichContent> {
  /// assetId → 原始像素高度。
  ///
  /// 高度来自题库的资产索引，只影响「行内还是块级」的判定，属于排版优化：
  /// 首帧先用 markup 里声明的 height 画出来，查到了再重建。
  /// 这样避免为了一个排版细节把整个内容区卡在加载态。
  Map<String, int> _heights = const {};
  String? _requestedMarkup;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureHeights();
  }

  @override
  void didUpdateWidget(covariant RichContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markup != widget.markup) _ensureHeights();
  }

  void _ensureHeights() {
    final markup = widget.markup;
    if (_requestedMarkup == markup) return;
    _requestedMarkup = markup;
    final assetIds = _parseSegments(markup)
        .where((segment) => segment.assetId != null)
        .map((segment) => segment.assetId!)
        .toList(growable: false);
    if (assetIds.isEmpty) {
      if (_heights.isNotEmpty) setState(() => _heights = const {});
      return;
    }
    ref
        .read(contentRepositoryProvider)
        .imageHeights(assetIds)
        .then((heights) {
          if (!mounted || _requestedMarkup != markup) return;
          if (heights.isEmpty) return;
          setState(() => _heights = heights);
        })
        .catchError((Object _) {
          // 查不到高度就沿用 markup 声明值，不影响内容展示。
        });
  }

  @override
  Widget build(BuildContext context) {
    final markup = widget.markup;
    final baseStyle =
        widget.style ??
        TextStyle(color: AppColors.ink, fontSize: 15, height: 1.65);
    final segments = _parseSegments(markup);
    final heights = _heights;
    // 行内判定：阈值内，或夹在句中（前后同一行都有文字）且高度不超句中上限。
    final inlineFlags = _resolveInlineFlags(segments, heights);

    // 文字与行内图必须同处一个 TextSpan 流，否则每张公式图都会独占一行。
    final paragraphs = <Widget>[];
    final inlineSpans = <InlineSpan>[];
    final blockImages = <_Segment>[];
    // 本段落内最高的行内图。分数公式图原始高度 28px（设计字号 15px），
    // 比 15 × 1.65 的行高还高；不把行高撞开，图的下半截就会被下一行文字盖住，
    // 分母直接看不见（1/8000 读成 1/800）。
    var maxInlineImageHeight = 0.0;

    void flushInline() {
      if (inlineSpans.isEmpty) return;
      var paragraphStyle = baseStyle;
      final fontSize = baseStyle.fontSize ?? _kInlineDesignFontSize;
      if (maxInlineImageHeight > 0 && fontSize > 0) {
        final baseLineHeight = baseStyle.height ?? 1.2;
        final neededLineHeight = maxInlineImageHeight / fontSize;
        if (neededLineHeight > baseLineHeight) {
          paragraphStyle = baseStyle.copyWith(height: neededLineHeight);
        }
      }
      final span = TextSpan(children: List.of(inlineSpans), style: paragraphStyle);
      // TextSpan 的行高不会因为 WidgetSpan 变高而自动撑开，
      // 单靠 style.height 改不动“一行有多高”——必须用 StrutStyle 把
      // 行盒（line box）的高度强制拉高到能装下行内公式图，
      // 否则分数图的下半截（分母）永远被下一行文字盖住。
      final strut = maxInlineImageHeight > 0
          ? StrutStyle(
              fontSize: paragraphStyle.fontSize,
              height: paragraphStyle.height,
              leadingDistribution: TextLeadingDistribution.even,
              forceStrutHeight: true,
            )
          : null;
      // Web 上用 SelectableText 会有两个真问题：
      // 1) 它在画布上盖一层 textarea，把点击拦下来，选项点文字没反应；
      // 2) 语义节点的文字变空，屏幕阅读器读不到题干和选项。
      // 桌面端可以按住鼠标选字，但刷题页更需要“点得动、读得出”，
      // 所以 web 退回普通 Text，原生端保留可选中。
      paragraphs.add(
        kIsWeb || !widget.selectable
            ? Text.rich(span, strutStyle: strut)
            : SelectableText.rich(span, strutStyle: strut),
      );
      inlineSpans.clear();
      maxInlineImageHeight = 0;
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
        if (inlineHeight > maxInlineImageHeight) {
          maxInlineImageHeight = inlineHeight;
        }
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
        final displayWidth = widget.targetHeight * ratio;
        final imageWidget = Image.memory(
          image.bytes,
          height: widget.targetHeight,
          width: displayWidth,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          // 按显示尺寸解码，而不是原图像素：行内公式图在这里只占三十来
          // 像素，而源图可能有一两千像素宽，不限制就是几百倍的内存浪费。
          cacheWidth: (displayWidth * MediaQuery.devicePixelRatioOf(context))
              .round(),
        );
        // 公式图是白底黑字导出的灰度位图（实测最亮像素只有 #585858），
        // 深色模式下直接把黑字放在深底上，分母几乎和背景融在一起。
        // 反色会把透明区变成白块，所以改成给它垫一层浅色底：
        // 保持原图黑字，只把背景提亮，对比度回到浅色模式的水平。
        final displayed = AppColors.isDark
            ? ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: ColoredBox(
                  color: const Color(0xFFE8E7E1),
                  child: imageWidget,
                ),
              )
            : imageWidget;
        // 行内公式图只是题干里的一个符号（实测多为 30x28 的小图），
        // 不需要放大看。之前它被做成可点按钮，答题页滑动滚动时手指
        // 落在公式上就会弹出全屏对话框，把正在作答的用户打断。
        // 块级题图（_BlockAssetImage）仍然可点放大。
        return displayed;
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
            child: Text(
              '图片缺失',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          );
        }
        final isLarge = image.height > _kBlockImageMaxHeight;
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final imageWidget = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 题图源图实测最宽 3000+ 像素，而列表里最宽也就屏幕宽度。
              // 按可用宽度解码，避免每张图都占几十 MB 的解码内存。
              final available = constraints.maxWidth;
              final cacheWidth = available.isFinite && available > 0
                  ? (available * devicePixelRatio).round()
                  : null;
              return Image.memory(
                image.bytes,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                gaplessPlayback: true,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stackTrace) => Text(
                  '图片无法显示',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              );
            },
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
      // 查看题图的底色不能跟着主题变：浅色主题下 AppColors.ink 是深色，
      // 而题图多为白底扫描件，深底会显得很割裂；反过来深色主题下 ink
      // 是浅色，白底题图就贴在白底上没了边界。用固定的中性深灰，
      // 两种主题下白底图都有明确边界。
      backgroundColor: const Color(0xFF2A2A2A),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    // 全屏看图是这个 App 里唯一需要高清的场景，按屏幕宽度
                    // 解码即可（再大也看不见），不必按原图像素。
                    cacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                  ),
                ),
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
