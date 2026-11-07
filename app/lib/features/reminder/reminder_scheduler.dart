import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/app_database.dart';

/// 每日练习提醒：默认提醒时间 20:00。
const int kDefaultReminderMinutes = 20 * 60;

/// 通知标识：固定 id，重排/取消都用它，保证同一条提醒只有一个实例。
const int _kReminderNotificationId = 42;
const String _kReminderChannelId = 'reminder';

/// 解析设置里的「提醒时间（分钟数 0..1439）」，非法值回退到默认 20:00。
int parseReminderMinutes(String? value) {
  final parsed = int.tryParse(value ?? '');
  if (parsed == null || parsed < 0 || parsed > 24 * 60 - 1) {
    return kDefaultReminderMinutes;
  }
  return parsed;
}

/// 分钟数格式化成 "HH:mm"（设置页展示用）。
String formatReminderTime(int minutesOfDay) {
  final clamped = minutesOfDay.clamp(0, 24 * 60 - 1);
  final hour = (clamped ~/ 60).toString().padLeft(2, '0');
  final minute = (clamped % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// 「今天 HH:MM」的下一次触发时刻，用 UTC 表示（配合
/// `matchDateTimeComponents: DateTimeComponents.time` 每天重复）。
///
/// 为什么用 UTC 而不是 tz.getLocation：timezone 包需要设备的 IANA 时区名
/// （例如 Asia/Shanghai），取这个名字要再引一个平台插件。国内设备固定
/// UTC+8 且无夏令时，用「本地时间 - 固定偏移」换算出触发点的 UTC 时刻
/// 就够了；代价是有夏令时的时区每年会漂 1 小时——本 App 面向国内公考
/// 场景，可接受，不为此多装一个插件。
DateTime nextDailyOccurrenceUtc(int minutesOfDay, DateTime nowLocal) {
  final clamped = minutesOfDay.clamp(0, 24 * 60 - 1);
  final utcMinutes = clamped - nowLocal.timeZoneOffset.inMinutes;
  final candidate = DateTime.utc(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
  ).add(Duration(minutes: utcMinutes));
  // 今天的时刻已经过了就排到明天（candidate 可能因为负偏移落在昨天，
  // 这时同样要 +1 天，直到严格晚于 now）。
  var when = candidate;
  while (!when.isAfter(nowLocal.toUtc())) {
    when = when.add(const Duration(days: 1));
  }
  return when;
}

/// 每日练习提醒的调度。
///
/// 纯本地通知：不联网、不上报、不带设备标识（与 README 的「不埋点」承诺
/// 一致）。用 inexact 模式调度，不需要 SCHEDULE_EXACT_ALARM 权限。
class ReminderScheduler {
  ReminderScheduler();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 原生端支持本地通知调度。
  bool get supported => true;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // 点通知只是把 App 拉起来，落在首页；不在这里做路由跳转。
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void _onNotificationTap(NotificationResponse details) {}

  /// Android 13+ 需要运行时通知权限；其他版本直接视为已授权。
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// 排一个每天 [minutesOfDay]（本地时刻）触发的提醒。
  Future<void> scheduleDaily(int minutesOfDay) async {
    await _ensureInitialized();
    final whenUtc = nextDailyOccurrenceUtc(minutesOfDay, DateTime.now());
    await _plugin.zonedSchedule(
      _kReminderNotificationId,
      '该刷题了',
      '今天来 20 题，保持手感',
      tz.TZDateTime.from(whenUtc, tz.UTC),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kReminderChannelId,
          '练习提醒',
          channelDescription: '每天固定时间提醒你来刷题',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // inexact：允许系统在省电窗口内小幅推迟，不需要精确闹钟权限。
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 取消提醒（关掉开关时调用；没排过也幂等）。
  Future<void> cancel() async {
    await _ensureInitialized();
    await _plugin.cancel(_kReminderNotificationId);
  }
}

/// Web 端（见 reminder_scheduler_web.dart）与原生端共用这份默认装配：
/// `final reminderScheduler = ReminderScheduler();`
final ReminderScheduler reminderScheduler = ReminderScheduler();

/// 调试用：debug 构建里可以打印下一次触发时间，验证调度没排错。
@visibleForTesting
String debugNextOccurrenceLabel(int minutesOfDay, DateTime now) {
  return nextDailyOccurrenceUtc(minutesOfDay, now).toIso8601String();
}

/// 从设置表同步系统通知排期：开关关→取消；开→按当前提醒时间重排。
/// 幂等，重复调用安全。设置页改设置后调用；App 冷启动也调用一次兜底
/// （覆盖改设置时没排上、或系统重启后排期丢失的情况）。
Future<void> syncReminderFromSettings(AppDatabase db) async {
  final enabled = await db.watchSetting('reminderEnabled').first;
  if (enabled != 'true') {
    await reminderScheduler.cancel();
    return;
  }
  final minutes = parseReminderMinutes(
    await db.watchSetting('reminderMinutesOfDay').first,
  );
  await reminderScheduler.scheduleDaily(minutes);
}
