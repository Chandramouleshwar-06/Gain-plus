package com.tracker1.gainplus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/**
 * Home-screen widget: today's workout, the streak and this week's count.
 * The app saves plans for the coming week and the days trained (see
 * home_widget_service.dart), so this stays right after midnight too.
 */
class GainPlusWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = LocalDate.now()
        val trained = (widgetData.getString("workout_days", "") ?: "")
            .split(',')
            .filter { it.isNotBlank() }
            .mapNotNull { runCatching { LocalDate.parse(it) }.getOrNull() }
            .toSet()

        // Same rule as the app: consecutive days ending today or yesterday.
        var day = if (trained.contains(today)) today else today.minusDays(1)
        var streak = 0
        while (trained.contains(day)) {
            streak++
            day = day.minusDays(1)
        }

        val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        val thisWeek = trained.count { !it.isBefore(monday) && !it.isAfter(today) }
        val target = widgetData.getInt("weekly_target", 3)

        val plan = (widgetData.getString("plan_$today", "") ?: "").split('|')
        val (eyebrow, title, subtitle) = when {
            trained.contains(today) -> Triple("TODAY", "WORKOUT DONE", "Nice work. Rest up.")
            plan.size == 2 && plan[0].isNotBlank() ->
                Triple("TODAY'S SESSION", plan[0].uppercase(), "${plan[1]} exercises · tap to start")
            widgetData.contains("weekly_target") -> Triple("TODAY", "NO WORKOUT PLANNED", "Tap to pick a plan")
            else -> Triple("GAIN+", "OPEN GAIN+", "Set up your training")
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.gainplus_widget).apply {
                setTextViewText(R.id.widget_eyebrow, eyebrow)
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)
                setTextViewText(R.id.widget_streak, if (streak == 1) "1 day streak" else "$streak day streak")
                setViewVisibility(R.id.widget_streak, if (streak > 0) View.VISIBLE else View.GONE)
                setTextViewText(R.id.widget_week, "$thisWeek/$target this week")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
