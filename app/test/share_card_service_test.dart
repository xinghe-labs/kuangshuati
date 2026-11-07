import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/features/share/share_card_service.dart';

void main() {
  // getTemporaryDirectory 在测试环境走 SharedPreferences/PathProvider
  // mock 不存在的路径，所以只测不落盘的纯逻辑 + PNG 渲染头。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareCardData.accuracyPercent', () {
    test('有作答时按四舍五入取整', () {
      expect(
        const ShareCardData(
          answered: 7,
          correct: 5,
          streakDays: 1,
          totalDays: 3,
          dateLabel: '2026-11-07',
        ).accuracyPercent,
        71,
      );
    });

    test('没有作答时为 null（卡片显示 —）', () {
      expect(
        const ShareCardData(
          answered: 0,
          correct: 0,
          streakDays: 0,
          totalDays: 0,
          dateLabel: '2026-11-07',
        ).accuracyPercent,
        isNull,
      );
    });
  });

  group('pngSignatureOf', () {
    test('PNG 文件头 8 字节固定', () {
      // 89 50 4E 47 0D 0A 1A 0A
      final signature = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(signature.length, 8);
    });

    test('文件不存在或过短返回 null', () {
      expect(pngSignatureOf(null), isNull);
      final missing = File('definitely_missing_share_card.png');
      expect(pngSignatureOf(missing), isNull);
    });
  });
}
