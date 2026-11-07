import 'dart:io';

import 'package:home_widget/home_widget.dart';

/// 桌面小组件（Android AppWidget）数据同步。
///
/// 小组件是纯增强功能：任何失败都静默吞掉，绝不影响练习主流程。
/// 原生端读取的是 home_widget 插件的 "HomeWidgetPreferences"
/// SharedPreferences，键约定与 StreakWidgetProvider.kt 保持一致。
const _keyTodayCount = 'widget_today_count';
const _keyStreakDays = 'widget_streak_days';

/// 把今日进度写入桌面小组件并触发刷新；非 Android 平台为 no-op。
Future<void> syncHomeWidget({
  required int todayCount,
  required int streakDays,
}) async {
  if (!Platform.isAndroid) return;
  try {
    await HomeWidget.saveWidgetData<int>(_keyTodayCount, todayCount);
    await HomeWidget.saveWidgetData<int>(_keyStreakDays, streakDays);
    await HomeWidget.updateWidget(
      androidName: 'StreakWidgetProvider',
    );
  } catch (_) {
    // 小组件刷新失败不影响主流程，静默即可。
  }
}
