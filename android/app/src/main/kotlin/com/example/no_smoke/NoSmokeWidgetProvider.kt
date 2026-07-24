package com.example.no_smoke

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/// Renders the home-screen counter widget from whatever the Dart side last
/// pushed via HomeWidget.saveWidgetData (see home_page.dart's
/// _updateHomeScreenWidget) — this class never talks to SQLite or any app
/// service directly, it only reads the small key/value snapshot the Dart
/// side already prepared.
class NoSmokeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.no_smoke_widget).apply {
                val days = widgetData.getInt("smokeFreeDays", 0)
                val breathLabel = widgetData.getString("breathScoreLabel", "") ?: ""
                val daysLabel = widgetData.getString("smokeFreeDaysLabel", "gun sigarasiz") ?: "gun sigarasiz"
                setTextViewText(R.id.widget_smoke_free_days, days.toString())
                setTextViewText(R.id.widget_smoke_free_label, daysLabel)
                setTextViewText(R.id.widget_breath_score, breathLabel)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
