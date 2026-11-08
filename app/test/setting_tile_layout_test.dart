import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 回归：settings_page._SettingTile 的行布局。
// 历史 bug：Expanded 与 Flexible 都是 flex:1，平分剩余空间，
// 导致右侧控件（箭头/开关）不贴卡片右缘、右侧留一大段空白。
// 修复后 trailing 作为非 flex 子项，必须贴 Row 右缘。
void main() {
  Future<Rect> pumpTile(WidgetTester tester, Widget trailing) async {
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            const Icon(Icons.add, size: 21),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('导入题库'),
                  SizedBox(height: 2),
                  Text('从本地 JSON 文件导入自制题库，替换当前题库'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 340, child: body))),
      ),
    );
    final rowRight = tester.getTopRight(find.byType(Row).first).dx;
    final tRight = tester.getTopRight(find.byWidget(trailing)).dx;
    expect(tRight, closeTo(rowRight, 0.5),
        reason: 'trailing 必须贴 Row 右缘（回归：flex 平分导致空白）');
    return tester.getRect(find.byWidget(trailing));
  }

  testWidgets('箭头 trailing 贴右', (tester) async {
    await pumpTile(tester, const Icon(Icons.chevron_right, size: 20));
  });

  testWidgets('开关 trailing 贴右', (tester) async {
    await pumpTile(tester, Switch(value: true, onChanged: (_) {}));
  });

  testWidgets('宽 trailing（三档字号场景）贴右且文字列折行不溢出', (tester) async {
    final rect = await pumpTile(
      tester,
      Container(
        key: const ValueKey('wide'),
        width: 150,
        height: 32,
        color: Colors.black12,
      ),
    );
    expect(rect.width, 150);
  });
}
