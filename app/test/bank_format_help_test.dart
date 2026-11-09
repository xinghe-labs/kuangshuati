import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuangshuati/features/content/bank_format_help.dart';
import 'package:kuangshuati/features/content/content_import_service.dart';

/// 设置页「自定义题库格式」展示的示例必须真的能导入，
/// 否则用户照着抄还会报错——比不给示例更糟。
void main() {
  group('自定义题库格式帮助', () {
    test('示例 JSON 能通过 parseBankJson 校验', () {
      final bank = parseBankJson(bankFormatExampleJson);

      expect(bank.papers, hasLength(1));
      final paper = bank.papers.single;
      expect(paper.id, 'P1');
      expect(paper.title, '我的第一套卷');
      expect(paper.questions, hasLength(2));

      // 第一题：选择题，选项与答案齐备。
      final choice = paper.questions[0];
      expect(choice.options.keys, ['A', 'B', 'C', 'D']);
      expect(choice.answers, ['B']);
      // 省略的字段走默认值：module 缺省「综合」，type 缺省空。
      expect(choice.module, '综合');
      expect(choice.type, isEmpty);

      // 第二题：v2 自评题，options 与 answer 同时省略。
      final selfAssessed = paper.questions[1];
      expect(selfAssessed.options, isEmpty);
      expect(selfAssessed.answers, isEmpty);
      expect(selfAssessed.type, '简答');
    });

    test('要点文案不为空', () {
      expect(bankFormatHints, isNotEmpty);
      for (final hint in bankFormatHints) {
        expect(hint.trim(), isNotEmpty);
      }
    });

    testWidgets('弹窗展示要点与示例，复制写入剪贴板，关闭可退出', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const BankFormatHelpDialog(),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('自定义题库格式'), findsOneWidget);
      expect(find.textContaining('format 固定为'), findsOneWidget);
      expect(find.textContaining('"formatVersion": 2'), findsOneWidget);

      await tester.tap(find.text('复制示例'));
      await tester.pumpAndSettle();
      expect(copied, bankFormatExampleJson);
      // 反馈必须在弹窗内部：SnackBar 会被弹窗遮住。
      expect(find.text('已复制'), findsOneWidget);
      expect(find.text('复制示例'), findsNothing);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('自定义题库格式'), findsNothing);
    });

    // 设置页历史上在 320 宽 + 大字号下向右溢出过，弹窗同样要钉住。
    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.6, 2.0]) {
        testWidgets('弹窗不溢出 ${width.toInt()}x$scale', (tester) async {
          tester.view.physicalSize = Size(width, 640) * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);

          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => errors.add(
            details.exception.toString().split('\n').first,
          );
          addTearDown(() => FlutterError.onError = previous);

          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(body: BankFormatHelpDialog()),
            ),
          );
          await tester.pumpAndSettle();

          expect(errors, isEmpty, reason: errors.join(' | '));
          expect(find.text('自定义题库格式'), findsOneWidget);
        });
      }
    }
  });
}
