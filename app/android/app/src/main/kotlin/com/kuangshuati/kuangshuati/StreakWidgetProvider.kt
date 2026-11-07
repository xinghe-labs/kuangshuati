package com.kuangshuati.kuangshuati

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * 桌面小组件：显示今日答题数与连续练习天数。
 *
 * 数据由 Flutter 侧通过 home_widget 插件写入名为
 * "HomeWidgetPreferences" 的 SharedPreferences（键：
 * widget_today_count / widget_streak_days），本类在
 * onUpdate / 数据变化时读取并渲染。
 */
class StreakWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs =
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val today = prefs.getInt("widget_today_count", 0)
        val streak = prefs.getInt("widget_streak_days", 0)
        val launcher = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending =
            PendingIntent.getActivity(
                context,
                0,
                launcher ?: Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        for (appWidgetId in appWidgetIds) {
            val views =
                RemoteViews(context.packageName, R.layout.streak_widget).apply {
                    setOnClickPendingIntent(R.id.widget_root, pending)
                    setTextViewText(
                        R.id.widget_today,
                        context.getString(R.string.widget_today_count, today),
                    )
                    setTextViewText(
                        R.id.widget_streak,
                        context.getString(R.string.widget_streak_days, streak),
                    )
                }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        /** 数据变化后由 Flutter 侧触发一次全量刷新。 */
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids =
                manager.getAppWidgetIds(
                    ComponentName(context, StreakWidgetProvider::class.java),
                )
            if (ids.isNotEmpty()) {
                StreakWidgetProvider().onUpdate(context, manager, ids)
            }
        }
    }
}
