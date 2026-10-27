import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class RichContent extends StatelessWidget {
  const RichContent(this.markup, {this.style, super.key});

  final String markup;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final segments = _parseSegments(markup);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final segment in segments)
          if (segment.assetId == null)
            Text(
              segment.text,
              style:
                  style ??
                  const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    height: 1.65,
                  ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: _AssetImage(assetId: segment.assetId!),
            ),
      ],
    );
  }
}

class _AssetImage extends ConsumerWidget {
  const _AssetImage({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(contentRepositoryProvider);
    return FutureBuilder<Uint8List?>(
      future: Future.sync(() => repository.imageBytes(assetId)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 88,
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: AppColors.softFill,
            child: const Text(
              '图片缺失',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          );
        }
        return Semantics(
          button: true,
          label: '查看题图',
          child: GestureDetector(
            onTap: () => _showImage(context, bytes),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 380),
              color: AppColors.softFill,
              padding: const EdgeInsets.all(8),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => const Text(
                  '图片无法显示',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImage(BuildContext context, Uint8List bytes) {
    showDialog<void>(
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
}

class _Segment {
  const _Segment.text(this.text) : assetId = null;
  const _Segment.image(this.assetId) : text = '';

  final String text;
  final String? assetId;
}

List<_Segment> _parseSegments(String input) {
  final segments = <_Segment>[];
  final markup = input.replaceAllMapped(
    RegExp('\ue000([^\ue001]+)\ue001'),
    (match) => '<img src="asset://${match.group(1)}">',
  );
  final imagePattern = RegExp(
    r'''<img\b[^>]*\bsrc\s*=\s*(["'])asset://([^"']+)\1[^>]*>''',
    caseSensitive: false,
  );
  var cursor = 0;
  for (final match in imagePattern.allMatches(markup)) {
    final text = _plainText(markup.substring(cursor, match.start));
    if (text.isNotEmpty) segments.add(_Segment.text(text));
    segments.add(_Segment.image(match.group(2)!));
    cursor = match.end;
  }
  final tail = _plainText(markup.substring(cursor));
  if (tail.isNotEmpty) segments.add(_Segment.text(tail));
  if (segments.isEmpty) segments.add(_Segment.text(_plainText(markup)));
  return segments;
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
