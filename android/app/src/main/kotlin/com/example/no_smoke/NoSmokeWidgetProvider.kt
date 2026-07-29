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
                // Was a count of calendar days since the quit date, which went
                // up whether or not the user smoked. Now the same slot carries
                // the reduction streak — days they actually stayed at or under
                // target — so the widget and the home page agree.
                val headline = widgetData.getInt("reductionStreakDays", 0)
                val breathLabel = widgetData.getString("breathScoreLabel", "") ?: ""
                val headlineLabel = widgetData.getString("reductionStreakLabel", "gun hedefte") ?: "gun hedefte"
                setTextViewText(R.id.widget_smoke_free_days, headline.toString())
                setTextViewText(R.id.widget_smoke_free_label, headlineLabel)
                setTextViewText(R.id.widget_breath_score, breathLabel)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
