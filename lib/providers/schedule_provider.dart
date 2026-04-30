import 'package:flutter/material.dart';
import '../models/course.dart';
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

  // Getters
  List<Course> get courses => _courses;
  List<TimeSlot> get timeSlots => _timeSlots;
  int get currentWeek => _currentWeek;
  int get maxPeriod => _maxPeriod;
  DateTime get semesterStart => _semesterStart;

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
    _courses = await _db.getCourses();
    _timeSlots = await _db.getTimeSlots();
    _maxPeriod = _timeSlots.isNotEmpty ? _timeSlots.last.period : 12;
    recalculateWeek();
    notifyListeners();
  }

  // 添加课程
  Future<void> addCourse(Course course) async {
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
}
