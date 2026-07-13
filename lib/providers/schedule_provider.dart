import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import '../models/schedule_set.dart';
import '../models/time_slot.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';
import '../utils/constants.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  SharedPreferences? _prefs;

  List<Course> _courses = [];
  List<TimeSlot> _timeSlots = List.from(defaultTimeSlots);
  int _currentWeek = 1;
  int _maxPeriod = 12;
  DateTime _semesterStart = defaultSemesterStart;

  List<ScheduleSet> _scheduleSets = [];
  String _activeSetId = defaultSetId;
  bool _initialized = false;
  int _syncRevision = 0;
  Future<void> _backgroundSyncQueue = Future<void>.value();

  // Getters
  List<Course> get courses => List.unmodifiable(_courses);
  List<TimeSlot> get timeSlots => List.unmodifiable(_timeSlots);
  int get currentWeek => _currentWeek;
  int get maxPeriod => _maxPeriod;
  DateTime get semesterStart => _semesterStart;
  List<ScheduleSet> get scheduleSets => List.unmodifiable(_scheduleSets);
  String get activeSetId => _activeSetId;
  bool get initialized => _initialized;

  ScheduleSet? get activeSet {
    if (_scheduleSets.isEmpty) return null;
    return _scheduleSets.firstWhere(
      (s) => s.id == _activeSetId,
      orElse: () => _scheduleSets.first,
    );
  }

  // 获取指定周几的课程 (已按节次排序)
  List<Course> getCoursesForDay(int week, int day) {
    return _courses
        .where((c) => c.day == day && c.isActiveInWeek(week))
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
  }

  // 获取今日课程
  List<Course> getTodayCourses() {
    final today = DateTime.now().weekday; // 1=Mon
    return getCoursesForDay(calculateCurrentWeek(_semesterStart), today);
  }

  // 计算当前周(基于学期开始日期)
  void recalculateWeek() {
    _currentWeek = calculateCurrentWeek(_semesterStart);
    notifyListeners();
  }

  /// 获取指定 DateTime 对应的课程列表
  /// 自动计算该日期对应的教学周和星期几
  List<Course> getCoursesForDate(DateTime date) {
    final week = calculateWeekForDate(date);
    final day = date.weekday; // 1=Mon
    return getCoursesForDay(week, day);
  }

  /// 计算指定日期对应的教学周
  int calculateWeekForDate(DateTime date) {
    return calculateTeachingWeek(_semesterStart, date);
  }

  // 切换周次
  void setWeek(int week) {
    _currentWeek = week.clamp(1, maxWeekCount);
    notifyListeners();
  }

  // 设置学期开始日期
  Future<void> setSemesterStart(DateTime date) async {
    _semesterStart = date;
    final set = activeSet;
    if (set != null) {
      set.semesterStart = date;
      await _db.updateScheduleSet(set);
    }
    recalculateWeek();
    _syncAll();
  }

  // 加载数据
  Future<void> loadData() async {
    _prefs = await SharedPreferences.getInstance();

    final needsReschedule = _prefs!.getBool('boot_reschedule_needed') ?? false;
    if (needsReschedule) {
      await _prefs!.remove('boot_reschedule_needed');
    }

    _scheduleSets = await _db.getScheduleSets();

    // 从 SharedPreferences 恢复上次活跃的课表集 ID
    final savedId = _prefs!.getString('activeSetId');
    if (savedId != null && _scheduleSets.any((s) => s.id == savedId)) {
      _activeSetId = savedId;
    } else if (_scheduleSets.isNotEmpty &&
        !_scheduleSets.any((s) => s.id == _activeSetId)) {
      _activeSetId = _scheduleSets.first.id;
    }
    if (_scheduleSets.isNotEmpty && savedId != _activeSetId) {
      await _prefs!.setString('activeSetId', _activeSetId);
    }

    // 设置学期开始日期
    final set = activeSet;
    if (set != null) {
      _semesterStart = set.semesterStart;
    }
    await _loadCoursesForActiveSet();
    _timeSlots = await _db.getTimeSlots();
    _maxPeriod = _timeSlots.isNotEmpty ? _timeSlots.last.period : 12;
    recalculateWeek();
    _initialized = true;
    notifyListeners();
    _syncAll();
  }

  Future<void> _loadCoursesForActiveSet() async {
    _courses = await _db.getCoursesBySet(_activeSetId);
  }

  // 切换课表集
  Future<void> switchSet(String setId) async {
    if (setId == _activeSetId) return;
    if (!_scheduleSets.any((set) => set.id == setId)) return;
    _activeSetId = setId;
    // 持久化当前活跃集 ID，供小部件背景回调读取
    await _prefs?.setString('activeSetId', _activeSetId);
    final set = activeSet;
    if (set != null) {
      _semesterStart = set.semesterStart;
    }
    await _loadCoursesForActiveSet();
    recalculateWeek();
    notifyListeners();
    _syncAll();
  }

  // 创建课表集
  Future<ScheduleSet> createSet(String name) async {
    final maxOrder = _scheduleSets.isEmpty
        ? 0
        : _scheduleSets.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b);
    final set = ScheduleSet(
      name: name,
      semesterStart: defaultSemesterStart,
      sortOrder: maxOrder + 1,
    );
    await _db.insertScheduleSet(set);
    _scheduleSets.add(set);
    notifyListeners();
    return set;
  }

  // 重命名课表集
  Future<void> renameSet(String id, String name) async {
    final set = _scheduleSets.firstWhere((s) => s.id == id);
    set.name = name;
    await _db.updateScheduleSet(set);
    notifyListeners();
  }

  // 删除课表集
  Future<void> deleteSet(String id) async {
    if (_scheduleSets.length <= 1) return; // 不能删除最后一个
    await _db.deleteScheduleSet(id);
    _scheduleSets.removeWhere((s) => s.id == id);
    // 如果删除的是当前活动集，切换到第一个（switchSet 内部已 notifyListeners）
    if (_activeSetId == id && _scheduleSets.isNotEmpty) {
      await switchSet(_scheduleSets.first.id);
    } else {
      notifyListeners();
    }
  }

  // 添加课程
  Future<void> addCourse(Course course) async {
    course.scheduleSetId = _activeSetId;
    await _db.insertCourse(course);
    final existingIndex = _courses.indexWhere((item) => item.id == course.id);
    if (existingIndex == -1) {
      _courses.add(course);
    } else {
      _courses[existingIndex] = course;
    }
    notifyListeners();
    _syncAll();
  }

  // 更新课程
  Future<void> updateCourse(Course course) async {
    await _db.updateCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
    }
    notifyListeners();
    _syncAll();
  }

  // 清空当前课表集所有课程
  Future<void> clearAllCourses() async {
    await _db.deleteCoursesBySet(_activeSetId);
    _courses.clear();
    notifyListeners();
    _syncAll();
  }

  // 删除课程
  Future<void> deleteCourse(String id) async {
    await _db.deleteCourse(id);
    _courses.removeWhere((c) => c.id == id);
    notifyListeners();
    _syncAll();
  }

  // 更新时间段
  Future<void> updateTimeSlot(TimeSlot slot) async {
    await _db.updateTimeSlot(slot);
    final index = _timeSlots.indexWhere((t) => t.period == slot.period);
    if (index != -1) {
      _timeSlots[index] = slot;
    } else {
      _timeSlots.add(slot);
    }
    _timeSlots.sort((a, b) => a.period.compareTo(b.period));
    _maxPeriod = _timeSlots.isNotEmpty ? _timeSlots.last.period : 12;
    notifyListeners();
    _syncAll();
  }

  // 保存所有时间段
  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    final normalized =
        slots
            .map(
              (slot) => TimeSlot(
                period: slot.period,
                startTime: slot.startTime,
                endTime: slot.endTime,
              ),
            )
            .toList()
          ..sort((a, b) => a.period.compareTo(b.period));
    await _db.saveTimeSlots(normalized);
    _timeSlots = normalized;
    _maxPeriod = normalized.isEmpty
        ? 12
        : normalized.map((slot) => slot.period).reduce((a, b) => a > b ? a : b);
    notifyListeners();
    _syncAll();
  }

  // 导出 JSON
  Future<String> exportJson() => _db.exportToJson();

  // 导入 JSON
  Future<Map<String, dynamic>> importJson(String jsonStr) async {
    final result = await _db.importFromJson(jsonStr);
    await loadData();
    return result;
  }

  // 导入课程到当前课表集
  Future<int> importCoursesToActiveSet(List<Course> courses) async {
    final fingerprints = _courses.map(_courseFingerprint).toSet();
    final coursesToInsert = <Course>[];
    for (final course in courses) {
      course.scheduleSetId = _activeSetId;
      if (fingerprints.add(_courseFingerprint(course))) {
        coursesToInsert.add(course);
      }
    }
    if (coursesToInsert.isEmpty) return 0;

    await _db.insertCourses(coursesToInsert);
    await _loadCoursesForActiveSet();
    notifyListeners();
    _syncAll();
    return coursesToInsert.length;
  }

  String _courseFingerprint(Course course) {
    final weeks = List<int>.from(course.activeWeeks)..sort();
    return [
      course.name.trim(),
      course.teacher.trim(),
      course.room.trim(),
      course.day,
      course.startPeriod,
      course.duration,
      weeks.join(','),
    ].join('|');
  }

  // 同步桌面小部件数据
  Future<void> _syncWidgetData() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      // 同步学期开始日期（小部件用于计算当前教学周）
      await WidgetService.syncSemesterStart(_semesterStart);

      // 获取今日课程
      final teachingWeek = calculateCurrentWeek(_semesterStart);
      final todayCourses = getCoursesForDay(
        teachingWeek,
        DateTime.now().weekday,
      );
      await WidgetService.syncAllCourses(_courses, _timeSlots);
      await WidgetService.syncTodayCourses(todayCourses, _timeSlots);

      // 同步周课表网格
      await WidgetService.syncWeekGrid(_courses, teachingWeek);

      // 更新所有小部件
      await WidgetService.updateAll();
    } catch (e) {
      // Widget同步失败不影响主功能
      debugPrint('Widget同步失败: $e');
    }
  }

  // 调度课程提醒通知
  Future<void> _scheduleNotifications() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return;
    }
    try {
      await NotificationService().scheduleWeeklyReminders(
        courses: _courses,
        timeSlots: _timeSlots,
        currentWeek: calculateCurrentWeek(_semesterStart),
        semesterStart: _semesterStart,
      );
    } catch (e) {
      debugPrint('通知调度失败: $e');
    }
  }

  // 同步所有后台任务（小部件 + 通知）
  void _syncAll() {
    final revision = ++_syncRevision;
    _backgroundSyncQueue = _backgroundSyncQueue
        .then((_) async {
          if (revision != _syncRevision) return;
          await Future.wait([_syncWidgetData(), _scheduleNotifications()]);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('后台同步失败: $error');
        });
  }
}
