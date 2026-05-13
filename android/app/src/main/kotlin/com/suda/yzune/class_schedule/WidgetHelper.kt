package com.suda.yzune.class_schedule

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

object WidgetHelper {

    const val KEY_TODAY_COURSES = "todayCourses"
    const val KEY_WEEK_START_DATE = "semesterStartDate"
    const val PREF_NAME = "HomeWidgetPreferences"

    fun dpToPx(context: Context, dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp, context.resources.displayMetrics
        ).toInt()
    }

    fun luminance(argb: Int): Double {
        val r = Color.red(argb) / 255.0
        val g = Color.green(argb) / 255.0
        val b = Color.blue(argb) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    fun isColorDark(argb: Int): Boolean = luminance(argb) < 0.5

    fun toArgbHex(colorValue: Int): String {
        return String.format("#%08X", colorValue)
    }

    fun getTodayDayOfWeek(): Int {
        return when (Calendar.getInstance().get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            Calendar.SUNDAY -> 7
            else -> 1
        }
    }

    fun getCurrentTeachingWeek(context: Context): Int {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        val weekStartStr = prefs.getString(KEY_WEEK_START_DATE, null)
            ?: return 1
        return try {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val startDate = sdf.parse(weekStartStr) ?: return 1
            val now = java.util.Date()
            val diffMs = now.time - startDate.time
            val diffDays = TimeUnit.MILLISECONDS.toDays(diffMs)
            if (diffDays < 0) 1 else (diffDays / 7 + 1).toInt()
        } catch (_: Exception) {
            1
        }
    }

    fun updateAllWidgets(context: Context) {
        val intent = Intent(context, ScheduleWidgetListProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val listIds = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, ScheduleWidgetListProvider::class.java))
        if (listIds.isNotEmpty()) {
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, listIds)
            context.sendBroadcast(intent)
        }

        val compactIntent = Intent(context, ScheduleWidgetCompactProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val compactIds = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, ScheduleWidgetCompactProvider::class.java))
        if (compactIds.isNotEmpty()) {
            compactIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, compactIds)
            context.sendBroadcast(compactIntent)
        }

        val weekIntent = Intent(context, ScheduleWidgetWeekProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val weekIds = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, ScheduleWidgetWeekProvider::class.java))
        if (weekIds.isNotEmpty()) {
            weekIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, weekIds)
            context.sendBroadcast(weekIntent)
        }
    }

    fun getTodayCourses(context: Context): List<Course> {
        val widgetPrefs = HomeWidgetPlugin.getData(context)
        val coursesJson = widgetPrefs.getString(KEY_TODAY_COURSES, null)
            ?: return emptyList()

        val courses = mutableListOf<Course>()
        val currentWeek = getCurrentTeachingWeek(context)
        val todayDay = getTodayDayOfWeek()

        try {
            val arr = JSONArray(coursesJson)
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val day = o.optInt("day", 0)
                if (day != todayDay) continue

                val startWeek = o.optInt("startWeek", 1)
                val endWeek = o.optInt("endWeek", 20)
                if (currentWeek < startWeek || currentWeek > endWeek) continue

                val weekType = o.optInt("weekType", 0)
                if (weekType == 1 && (currentWeek % 2 == 0)) continue
                if (weekType == 2 && (currentWeek % 2 == 1)) continue

                courses.add(
                    Course(
                        id = o.optInt("id", 0),
                        name = o.optString("name", ""),
                        room = o.optString("room", ""),
                        teacher = o.optString("teacher", ""),
                        day = day,
                        startPeriod = o.optInt("startPeriod", 1),
                        duration = o.optInt("duration", 2),
                        startWeek = startWeek,
                        endWeek = endWeek,
                        weekType = weekType,
                        colorValue = o.optInt("colorValue", 0xFF2196F3.toInt())
                    )
                )
            }
        } catch (_: Exception) {
        }

        return courses
    }

    fun updateListView(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        courses: List<Course>
    ) {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_list)

        if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_course_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_course_list, View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.removeAllViews(R.id.widget_course_list)

            val sorted = courses.sortedBy { it.startPeriod }
            for (course in sorted) {
                val item = RemoteViews(context.packageName, R.layout.schedule_widget_list_item)
                item.setInt(
                    R.id.item_color_bar, "setBackgroundColor",
                    Color.parseColor(toArgbHex(course.colorValue))
                )
                item.setTextViewText(R.id.item_course_name, course.name)
                val startH = ((course.startPeriod + 1) / 2 + 7).toString()
                val startM = if (course.startPeriod % 2 == 1) "00" else "50"
                val endP = course.startPeriod + course.duration - 1
                val endH = ((endP + 1) / 2 + 7).toString()
                val endM = if (endP % 2 == 1) "00" else "50"
                item.setTextViewText(
                    R.id.item_course_time,
                    "${startH}:${startM} - ${endH}:${endM}"
                )
                val room = if (course.room.isNotBlank()) course.room else ""
                item.setTextViewText(R.id.item_course_room, room)
                views.addView(R.id.widget_course_list, item)
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateCompactView(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        courses: List<Course>
    ) {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_compact)

        if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_compact_content, View.GONE)
            views.setViewVisibility(R.id.widget_compact_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_compact_content, View.VISIBLE)
            views.setViewVisibility(R.id.widget_compact_empty, View.GONE)

            val sorted = courses.sortedBy { it.startPeriod }
            val now = Calendar.getInstance()
            val currentMinuteOfDay = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

            var active: Course? = null
            var activeStartTime = 0
            var activeEndTime = 0
            var next: Course? = null

            for (course in sorted) {
                val courseStart = periodToMinute(course.startPeriod)
                val courseEnd = periodToMinute(course.startPeriod + course.duration - 1) + 45
                if (currentMinuteOfDay in courseStart until courseEnd) {
                    active = course
                    activeStartTime = courseStart
                    activeEndTime = courseEnd
                    break
                }
                if (courseStart > currentMinuteOfDay && next == null) {
                    next = course
                }
            }

            val course = active ?: next ?: sorted.first()
            val label = if (active != null) "当前课程" else "下一节课"
            views.setTextViewText(R.id.widget_compact_label, label)
            views.setTextViewText(R.id.widget_compact_name, course.name)

            val startH = ((course.startPeriod + 1) / 2 + 7).toString()
            val startM = if (course.startPeriod % 2 == 1) "00" else "50"
            val endP = course.startPeriod + course.duration - 1
            val endH = ((endP + 1) / 2 + 7).toString()
            val endM = if (endP % 2 == 1) "00" else "50"
            views.setTextViewText(
                R.id.widget_compact_time,
                "${startH}:${startM} - ${endH}:${endM}"
            )

            val room = if (course.room.isNotBlank()) course.room else ""
            views.setTextViewText(R.id.widget_compact_room, room)

            val bgColor = course.colorValue
            views.setInt(
                R.id.widget_compact_progress_bg, "setBackgroundColor",
                Color.parseColor(toArgbHex(bgColor and 0x33FFFFFF))
            )

            val progress = if (active != null && activeEndTime > activeStartTime) {
                val elapsed = currentMinuteOfDay - activeStartTime
                val total = activeEndTime - activeStartTime
                (elapsed * 100 / total).coerceIn(0, 100)
            } else {
                0
            }

            val containerWidth = dpToPx(context, 48f)
            val fgWidth = (containerWidth * progress / 100f).toInt().coerceIn(0, containerWidth)
            views.setViewLayoutWidth(R.id.widget_compact_progress_fg, fgWidth.toFloat(), TypedValue.COMPLEX_UNIT_PX)
            views.setInt(
                R.id.widget_compact_progress_fg, "setBackgroundColor",
                Color.parseColor(toArgbHex(bgColor))
            )
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    fun updateWeekView(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        courses: List<Course>
    ) {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_week)

        if (courses.isEmpty()) {
            views.setViewVisibility(R.id.widget_week_content, View.GONE)
            views.setViewVisibility(R.id.widget_week_empty, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_week_content, View.VISIBLE)
            views.setViewVisibility(R.id.widget_week_empty, View.GONE)

            val dayColors = mutableMapOf<Int, MutableList<Int>>()
            for (c in courses) {
                dayColors.getOrPut(c.day) { mutableListOf() }.add(c.colorValue)
            }

            val cellIds = intArrayOf(
                R.id.week_cell_mon, R.id.week_cell_tue, R.id.week_cell_wed,
                R.id.week_cell_thu, R.id.week_cell_fri, R.id.week_cell_sat,
                R.id.week_cell_sun
            )

            val todayDay = getTodayDayOfWeek()
            val blockHeightPx = dpToPx(context, 14f)
            val blockMarginPx = dpToPx(context, 1f)

            for (dayIndex in 0 until 7) {
                val cellId = cellIds[dayIndex]
                views.removeAllViews(cellId)
                val colors = dayColors[dayIndex + 1] ?: emptyList()
                val count = colors.size.coerceAtMost(3)

                for (j in 0 until count) {
                    val block = RemoteViews(context.packageName, R.layout.widget_color_block)
                    block.setInt(
                        R.id.color_block_view, "setBackgroundColor",
                        Color.parseColor(toArgbHex(colors[j]))
                    )
                    views.addView(cellId, block)
                }

                if (dayIndex + 1 == todayDay) {
                    views.setInt(cellId, "setBackgroundColor", 0x33000000)
                }
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun periodToMinute(period: Int): Int {
        return when {
            period <= 0 -> 8 * 60
            period % 2 == 1 -> (7 + (period + 1) / 2) * 60
            else -> (7 + period / 2) * 60 + 50
        }
    }

    data class Course(
        val id: Int,
        val name: String,
        val room: String,
        val teacher: String,
        val day: Int,
        val startPeriod: Int,
        val duration: Int,
        val startWeek: Int,
        val endWeek: Int,
        val weekType: Int,
        val colorValue: Int
    )
}
