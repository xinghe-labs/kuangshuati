import '../../data/database/app_database.dart';

/// Web 端的提醒调度：浏览器没有系统通知调度能力，全部 no-op。
///
/// 与 reminder_scheduler.dart 的接口保持一致，但 [supported] 恒为 false，
/// 设置页据此隐藏「每日练习提醒」入口；纯函数（解析/格式化/下次触发计算）
/// 也保留一份，保证双端行为一致。
const int kDefaultReminderMinutes = 20 * 60;

int parseReminderMinutes(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 0 || parsed > 24 * 60 - 1) {
    return kDefaultReminderMinutes;
  }
  return parsed;
}

String formatReminderTime(int minutesOfDay) {
  final clamped = minutesOfDay.clamp(0, 24 * 60 - 1);
  final hour = (clamped ~/ 60).toString().padLeft(2, '0');
  final minute = (clamped % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime nextDailyOccurrenceUtc(int minutesOfDay, DateTime nowLocal) {
  final clamped = minutesOfDay.clamp(0, 24 * 60 - 1);
  final utcMinutes = clamped - nowLocal.timeZoneOffset.inMinutes;
  final candidate = DateTime.utc(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
  ).add(Duration(minutes: utcMinutes));
  var when = candidate;
  while (!when.isAfter(nowLocal.toUtc())) {
    when = when.add(const Duration(days: 1));
  }
  return when;
}

class ReminderScheduler {
  const ReminderScheduler();

  bool get supported => false;

  Future<bool> requestPermission() async => false;

  Future<void> scheduleDaily(int minutesOfDay) async {}

  Future<void> cancel() async {}
}

/// Web 端无系统通知，同步为 no-op（保持与原生端同名同签名）。
Future<void> syncReminderFromSettings(AppDatabase db) async {}

const ReminderScheduler reminderScheduler = ReminderScheduler();
