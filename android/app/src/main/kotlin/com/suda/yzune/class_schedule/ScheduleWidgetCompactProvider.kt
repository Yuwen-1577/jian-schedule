package com.suda.yzune.class_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class ScheduleWidgetCompactProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val courses = WidgetHelper.getTodayCourses(context)
        for (appWidgetId in appWidgetIds) {
            WidgetHelper.updateCompactView(context, appWidgetManager, appWidgetId, courses)
        }
    }
}
