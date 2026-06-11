package com.suda.yzune.class_schedule

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class ScheduleWidgetWeekProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val courses = WidgetHelper.getTodayCourses(context)
        for (appWidgetId in appWidgetIds) {
            WidgetHelper.updateWeekView(context, appWidgetManager, appWidgetId, courses)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        WidgetHelper.handleOnReceive(context, intent, ScheduleWidgetWeekProvider::class.java)
    }
}
