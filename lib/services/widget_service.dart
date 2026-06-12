import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../utils/constants.dart';

/// 桌面小部件数据同步服务
/// 通过 home_widget 包与原生 Android AppWidget 通信
class WidgetService {
  /// 同步学期开始日期到桌面小部件
  /// Kotlin 端用此日期计算当前教学周
  static Future<void> syncSemesterStart(DateTime semesterStart) async {
    // 格式: yyyy-MM-dd，与 Kotlin SimpleDateFormat 匹配
    final isoDate =
        '${semesterStart.year}-${semesterStart.month.toString().padLeft(2, '0')}-${semesterStart.day.toString().padLeft(2, '0')}';
    await HomeWidget.saveWidgetData<String>('semesterStartDate', isoDate);
  }

  /// 同步今日课程到桌面小部件
  static Future<void> syncTodayCourses(
    List<Course> courses,
    List<TimeSlot> timeSlots,
  ) async {
    final List<Map<String, dynamic>> courseData = courses.map((course) {
      // 从 timeSlots 获取真实上课时间
      String startTime = '';
      String endTime = '';
      final startIdx = course.startPeriod - 1;
      final endIdx = course.endPeriod - 1;
      if (startIdx >= 0 && startIdx < timeSlots.length) {
        startTime = timeSlots[startIdx].startTime;
      }
      if (endIdx >= 0 && endIdx < timeSlots.length) {
        endTime = timeSlots[endIdx].endTime;
      }

      return {
        'id': stableId(course.id),
        'name': course.name,
        'room': course.room,
        'teacher': course.teacher,
        'day': course.day,
        'startPeriod': course.startPeriod,
        'duration': course.duration,
        'startWeek': course.startWeek,
        'endWeek': course.endWeek,
        'weekType': course.weekType,
        'colorValue': course.colorValue,
        'startTime': startTime,
        'endTime': endTime,
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(
      'todayCourses',
      jsonEncode(courseData),
    );

    // 同步时间槽数据到小部件，用于计算进度条等
    final List<Map<String, dynamic>> slotsData = timeSlots.map((slot) {
      return {
        'period': slot.period,
        'startTime': slot.startTime,
        'endTime': slot.endTime,
      };
    }).toList();
    await HomeWidget.saveWidgetData<String>(
      'timeSlots',
      jsonEncode(slotsData),
    );

    // 更新所有相关的小部件 provider
    await _updateAllProviders();
  }

  /// 同步当前课程进度到桌面小部件
  /// 用于紧凑模式小部件显示当前正在上的课
  static Future<void> syncCurrentProgress(
    Course? currentCourse,
    double progress,
    List<TimeSlot> timeSlots,
  ) async {
    Map<String, dynamic>? progressData;

    if (currentCourse != null) {
      final startSlotIndex = currentCourse.startPeriod - 1;
      final endSlotIndex = currentCourse.endPeriod - 1;

      String startTime = '';
      String endTime = '';

      if (startSlotIndex >= 0 && startSlotIndex < timeSlots.length) {
        startTime = timeSlots[startSlotIndex].startTime;
      }
      if (endSlotIndex >= 0 && endSlotIndex < timeSlots.length) {
        endTime = timeSlots[endSlotIndex].endTime;
      }

      progressData = {
        'name': currentCourse.name,
        'room': currentCourse.room,
        'teacher': currentCourse.teacher,
        'startTime': startTime,
        'endTime': endTime,
        'colorValue': currentCourse.colorValue,
        'progress': progress,
      };
    }

    await HomeWidget.saveWidgetData<String>(
      'currentProgress',
      jsonEncode(progressData),
    );

    // 更新紧凑模式小部件
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetCompactProvider',
    );
  }

  /// 同步周课表网格到桌面小部件
  /// 格式化本周7天的课程，按星期分组
  static Future<void> syncWeekGrid(
    List<Course> courses,
    int currentWeek,
  ) async {
    // 星期映射: 1=周一 ... 7=周日
    final Map<String, List<Map<String, dynamic>>> weekGrid = {
      'monday': [],
      'tuesday': [],
      'wednesday': [],
      'thursday': [],
      'friday': [],
      'saturday': [],
      'sunday': [],
    };

    final dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    // 按星期分组课程
    for (final course in courses) {
      if (course.isActiveInWeek(currentWeek)) {
        final dayIndex = course.day - 1; // day 从1开始
        if (dayIndex >= 0 && dayIndex < 7) {
          weekGrid[dayNames[dayIndex]]!.add({
            'name': course.name,
            'startPeriod': course.startPeriod,
            'duration': course.duration,
            'colorValue': course.colorValue,
          });
        }
      }
    }

    await HomeWidget.saveWidgetData<String>(
      'weekGrid',
      jsonEncode(weekGrid),
    );

    // 更新周视图小部件
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetWeekProvider',
    );
  }

  /// 更新所有小部件 provider
  static Future<void> _updateAllProviders() async {
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetListProvider',
    );
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetCompactProvider',
    );
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetWeekProvider',
    );
  }

  /// 触发所有小部件更新
  static Future<void> updateAll() async {
    await _updateAllProviders();
  }
}
