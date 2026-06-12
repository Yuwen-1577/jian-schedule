package com.suda.yzune.class_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class ScheduleWidgetWeekProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val courses = WidgetHelper.getAllCoursesForCurrentWeek(context)
        for (appWidgetId in appWidgetIds) {
            WidgetHelper.updateWeekView(context, appWidgetManager, appWidgetId, courses)
        }
    }
}
