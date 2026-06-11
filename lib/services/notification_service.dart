import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/course.dart';
import '../models/time_slot.dart';

/// 课程提醒通知服务
/// 封装 flutter_local_notifications，提供课程提醒的调度和管理
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// FNV-1a 哈希，将 UUID 字符串转为稳定的 32 位正整数
  static int _stableId(String uuid) {
    int hash = 0x811c9dc5; // FNV offset basis
    for (int i = 0; i < uuid.length; i++) {
      hash ^= uuid.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, 32-bit
    }
    return hash & 0x7FFFFFFF; // 确保正数
  }

  /// 初始化通知服务
  Future<bool> initialize() async {
    if (_initialized) return true;

    // 初始化时区数据
    tz.initializeTimeZones();

    // Android 初始化
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    _initialized = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    ) ?? false;

    // 请求 Android 13+ 权限
    await _requestPermissions();

    return _initialized;
  }

  /// 请求通知权限
  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// 通知点击回调
  void _onNotificationTapped(NotificationResponse response) {
    // 打开 app 即可，不需要特殊处理
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// 为当前周的所有课程调度提醒通知
  /// [courses] 当前课表集的课程列表
  /// [timeSlots] 时间槽列表（用于计算具体提醒时间）
  /// [currentWeek] 当前教学周
  Future<void> scheduleWeeklyReminders({
    required List<Course> courses,
    required List<TimeSlot> timeSlots,
    required int currentWeek,
    required DateTime semesterStart,
  }) async {
    if (!_initialized) return;

    // 先取消所有已有通知
    await cancelAll();

    final now = DateTime.now();
    int scheduledCount = 0;

    for (final course in courses) {
      if (course.reminderMinutesBefore <= 0) continue;
      if (!course.isActiveInWeek(currentWeek)) continue;

      // 计算该课程在本周的具体日期
      final weekStart =
          semesterStart.add(Duration(days: (currentWeek - 1) * 7));
      final courseDate =
          weekStart.add(Duration(days: course.day - 1)); // day 从 1 开始

      // 获取上课开始时间
      final startIdx = course.startPeriod - 1;
      if (startIdx < 0 || startIdx >= timeSlots.length) continue;

      final slot = timeSlots[startIdx];
      final timeParts = slot.startTime.split(':');
      if (timeParts.length < 2) continue;
      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      if (hour == null || minute == null) continue;

      // 构建完整的上课时间
      final classTime = DateTime(
        courseDate.year,
        courseDate.month,
        courseDate.day,
        hour,
        minute,
      );

      // 提前提醒时间
      final reminderTime =
          classTime.subtract(Duration(minutes: course.reminderMinutesBefore));

      // 跳过已过去的提醒
      if (reminderTime.isBefore(now)) continue;

      // 调度通知
      final id = _stableId(course.id);
      final body = course.room.isNotEmpty
          ? '${course.room}${course.teacher.isNotEmpty ? " · ${course.teacher}" : ""}'
          : (course.teacher.isNotEmpty ? course.teacher : '');

      await _plugin.zonedSchedule(
        id,
        '${course.name} - ${course.reminderMinutesBefore}分钟后上课',
        body,
        tz.TZDateTime.from(reminderTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'course_reminder',
            '课程提醒',
            channelDescription: '上课前自动提醒',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: course.id,
      );
      scheduledCount++;
    }

    debugPrint('Scheduled $scheduledCount course reminders for week $currentWeek');
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// 取消指定课程的通知
  Future<void> cancelForCourse(String courseId) async {
    if (!_initialized) return;
    final id = _stableId(courseId);
    await _plugin.cancel(id);
  }

  /// 检查通知权限状态
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    return true; // 其他平台默认可用
  }
}
