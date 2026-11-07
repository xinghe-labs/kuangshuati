import 'package:flutter_test/flutter_test.dart';

import 'package:kuangshuati/features/reminder/reminder_scheduler.dart';

void main() {
  group('parseReminderMinutes', () {
    test('空/非法值回退默认 20:00', () {
      expect(parseReminderMinutes(null), kDefaultReminderMinutes);
      expect(parseReminderMinutes(''), kDefaultReminderMinutes);
      expect(parseReminderMinutes('abc'), kDefaultReminderMinutes);
      expect(parseReminderMinutes('-1'), kDefaultReminderMinutes);
      expect(parseReminderMinutes('1440'), kDefaultReminderMinutes);
    });

    test('合法值原样保留', () {
      expect(parseReminderMinutes('0'), 0);
      expect(parseReminderMinutes('600'), 600);
      expect(parseReminderMinutes('1439'), 1439);
    });
  });

  group('formatReminderTime', () {
    test('HH:mm 格式', () {
      expect(formatReminderTime(0), '00:00');
      expect(formatReminderTime(609), '10:09');
      expect(formatReminderTime(1200), '20:00');
    });
  });

  group('nextDailyOccurrenceUtc', () {
    // 用 UTC 构造 nowLocal（timeZoneOffset = 0），使期望值与宿主时区无关。
    test('今天的时刻还没到：排今天', () {
      final when = nextDailyOccurrenceUtc(
        1200, // 20:00
        DateTime.utc(2026, 11, 7, 10),
      );
      expect(when, DateTime.utc(2026, 11, 7, 20, 0));
    });

    test('今天的时刻已过：排明天', () {
      final when = nextDailyOccurrenceUtc(
        360, // 06:00
        DateTime.utc(2026, 11, 7, 10),
      );
      expect(when, DateTime.utc(2026, 11, 8, 6, 0));
    });

    test('时刻正好等于 now：也算已过，排明天', () {
      final when = nextDailyOccurrenceUtc(
        600, // 10:00
        DateTime.utc(2026, 11, 7, 10),
      );
      expect(when, DateTime.utc(2026, 11, 8, 10, 0));
    });

    test('本地时刻早于 UTC 的滚动回绕（负偏移场景）', () {
      // 「本地」= UTC 23:00，要排本地次日 01:00 → UTC 次日 01:00。
      final when = nextDailyOccurrenceUtc(
        60,
        DateTime.utc(2026, 11, 7, 23),
      );
      expect(when, DateTime.utc(2026, 11, 8, 1, 0));
    });

    test('结果严格晚于 now，且间隔小于 24 小时', () {
      final now = DateTime.utc(2026, 11, 7, 13, 37);
      for (final minutes in [0, 1, 720, 1439]) {
        final when = nextDailyOccurrenceUtc(minutes, now);
        expect(when.isAfter(now), isTrue, reason: 'minutes=$minutes');
        expect(when.difference(now) <= const Duration(hours: 24), isTrue,
            reason: 'minutes=$minutes');
      }
    });
  });
}
