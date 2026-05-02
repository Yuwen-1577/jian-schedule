import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/schedule_set.dart';
import '../models/time_slot.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class ScheduleProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Course> _courses = [];
  List<TimeSlot> _timeSlots = defaultTimeSlots;
  int _currentWeek = 1;
  int _maxPeriod = 12;
  DateTime _semesterStart = defaultSemesterStart;

  List<ScheduleSet> _scheduleSets = [];
  String _activeSetId = 'default';

  // Getters
  List<Course> get courses => _courses;
  List<TimeSlot> get timeSlots => _timeSlots;
  int get currentWeek => _currentWeek;
  int get maxPeriod => _maxPeriod;
  DateTime get semesterStart => _semesterStart;
  List<ScheduleSet> get scheduleSets => _scheduleSets;
  String get activeSetId => _activeSetId;

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
    return getCoursesForDay(_currentWeek, today);
  }

  // 计算当前周(基于学期开始日期)
  void recalculateWeek() {
    _currentWeek = calculateCurrentWeek(_semesterStart);
    notifyListeners();
  }

  // 切换周次
  void setWeek(int week) {
    _currentWeek = week.clamp(1, 25);
    notifyListeners();
  }

  // 设置学期开始日期
  void setSemesterStart(DateTime date) {
    _semesterStart = date;
    recalculateWeek();
  }

  // 加载数据
  Future<void> loadData() async {
    _scheduleSets = await _db.getScheduleSets();
    // 确保 activeSetId 存在
    if (_scheduleSets.isNotEmpty &&
        !_scheduleSets.any((s) => s.id == _activeSetId)) {
      _activeSetId = _scheduleSets.first.id;
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
    notifyListeners();
  }

  Future<void> _loadCoursesForActiveSet() async {
    _courses = await _db.getCoursesBySet(_activeSetId);
  }

  // 切换课表集
  Future<void> switchSet(String setId) async {
    if (setId == _activeSetId) return;
    _activeSetId = setId;
    final set = activeSet;
    if (set != null) {
      _semesterStart = set.semesterStart;
    }
    await _loadCoursesForActiveSet();
    recalculateWeek();
    notifyListeners();
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
    // 如果删除的是当前活动集，切换到第一个
    if (_activeSetId == id && _scheduleSets.isNotEmpty) {
      await switchSet(_scheduleSets.first.id);
    }
    notifyListeners();
  }

  // 添加课程
  Future<void> addCourse(Course course) async {
    course.scheduleSetId = _activeSetId;
    await _db.insertCourse(course);
    _courses.add(course);
    notifyListeners();
  }

  // 更新课程
  Future<void> updateCourse(Course course) async {
    await _db.updateCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) {
      _courses[index] = course;
    }
    notifyListeners();
  }

  // 删除课程
  Future<void> deleteCourse(String id) async {
    await _db.deleteCourse(id);
    _courses.removeWhere((c) => c.id == id);
    notifyListeners();
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
  }

  // 保存所有时间段
  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    await _db.saveTimeSlots(slots);
    _timeSlots = List.from(slots);
    _maxPeriod = slots.isNotEmpty ? slots.last.period : 12;
    notifyListeners();
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
  Future<void> importCoursesToActiveSet(List<Course> courses) async {
    for (final course in courses) {
      course.scheduleSetId = _activeSetId;
    }
    await _db.insertCourses(courses);
    _courses.addAll(courses);
    notifyListeners();
  }
}
