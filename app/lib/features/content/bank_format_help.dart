import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 自定义题库导入格式的最小示例。
///
/// 设置页「自定义题库格式」把它原样展示并允许复制；测试
/// （test/bank_format_help_test.dart）用 [parseBankJson] 校验它确实能导入，
/// 避免示例和校验器悄悄跑偏。
///
/// 完整字段表见仓库 docs/question-bank-format.md。
const bankFormatExampleJson = '''{
  "format": "kuangshuati-bank",
  "formatVersion": 2,
  "name": "我的题库",
  "papers": [
    {
      "id": "P1",
      "title": "我的第一套卷",
      "questions": [
        {
          "id": "Q1",
          "stem": "1 + 1 = ?",
          "options": {"A": "1", "B": "2", "C": "3", "D": "4"},
          "answer": ["B"]
        },
        {
          "id": "Q2",
          "type": "简答",
          "stem": "简述你对离线优先的理解。"
        }
      ]
    }
  ]
}''';

/// 格式要点，逐条展示在帮助弹窗里。
const bankFormatHints = <String>[
  'format 固定为 "kuangshuati-bank"，formatVersion 填 2',
  'papers[] 每套卷要有 id、title、questions[]；每题要有 id、stem',
  '选择题给 options 与 answer（answer 是选项键数组，如 ["B"]）',
  'v2 自评题：options 与 answer 同时省略，答完自己判对错',
  '图片放进 images（图片ID → {mime, data}），题干用 [[img:图片ID]] 引用',
  'year/region/paperType/durationSeconds/module/type 都可省略，有默认值',
];

/// 设置页「自定义题库格式」的说明弹窗：要点 + 可复制的最小示例。
///
/// 不链外网文档，保持离线可用；完整字段表在仓库 docs/question-bank-format.md。
class BankFormatHelpDialog extends StatefulWidget {
  const BankFormatHelpDialog({super.key});

  @override
  State<BankFormatHelpDialog> createState() => _BankFormatHelpDialogState();
}

class _BankFormatHelpDialogState extends State<BankFormatHelpDialog> {
  /// 复制反馈做在弹窗内部：SnackBar 会被弹窗遮住，真机上等于没提示。
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('自定义题库格式'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('把题库整理成一个 JSON 文件，再用「导入题库」导入。要点：'),
              const SizedBox(height: 8),
              for (final hint in bankFormatHints)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('· $hint'),
                ),
              const SizedBox(height: 12),
              const Text(
                '最小示例（可直接复制修改）：',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  bankFormatExampleJson,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              const ClipboardData(text: bankFormatExampleJson),
            );
            if (!mounted) return;
            setState(() => _copied = true);
          },
          child: Text(_copied ? '已复制' : '复制示例'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
