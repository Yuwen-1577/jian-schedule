import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/course.dart';
import '../models/schedule_set.dart';
import '../models/time_slot.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'schedule.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schedule_sets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        semesterStart TEXT NOT NULL,
        sortOrder INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        room TEXT DEFAULT '',
        teacher TEXT DEFAULT '',
        day INTEGER NOT NULL,
        startPeriod INTEGER NOT NULL,
        duration INTEGER DEFAULT 2,
        startWeek INTEGER DEFAULT 1,
        endWeek INTEGER DEFAULT 20,
        weekType INTEGER DEFAULT 0,
        colorValue INTEGER DEFAULT 0xFF4CAF50,
        note TEXT DEFAULT '',
        scheduleSetId TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE time_slots (
        period INTEGER PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL
      )
    ''');
    // 插入默认课表集
    await db.insert('schedule_sets', {
      'id': 'default',
      'name': '我的课表',
      'semesterStart': DateTime(2025, 2, 17).toIso8601String(),
      'sortOrder': 0,
    });
    // 插入默认时间表
    for (final slot in defaultTimeSlots) {
      await db.insert('time_slots', slot.toMap());
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 创建 schedule_sets 表
      await db.execute('''
        CREATE TABLE schedule_sets (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          semesterStart TEXT NOT NULL,
          sortOrder INTEGER DEFAULT 0
        )
      ''');
      // 插入默认课表集
      await db.insert('schedule_sets', {
        'id': 'default',
        'name': '我的课表',
        'semesterStart': DateTime(2025, 2, 17).toIso8601String(),
        'sortOrder': 0,
      });
      // courses 表新增 scheduleSetId 列
      await db.execute(
          "ALTER TABLE courses ADD COLUMN scheduleSetId TEXT DEFAULT ''");
      // 现有课程归入默认集
      await db.update('courses', {'scheduleSetId': 'default'});
    }
  }

  // ============ 课表集 CRUD ============

  Future<List<ScheduleSet>> getScheduleSets() async {
    final db = await database;
    final maps = await db.query('schedule_sets', orderBy: 'sortOrder ASC');
    return maps.map((map) => ScheduleSet.fromMap(map)).toList();
  }

  Future<ScheduleSet?> getScheduleSet(String id) async {
    final db = await database;
    final maps =
        await db.query('schedule_sets', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ScheduleSet.fromMap(maps.first);
  }

  Future<void> insertScheduleSet(ScheduleSet set) async {
    final db = await database;
    await db.insert('schedule_sets', set.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateScheduleSet(ScheduleSet set) async {
    final db = await database;
    await db.update('schedule_sets', set.toMap(),
        where: 'id = ?', whereArgs: [set.id]);
  }

  Future<void> deleteScheduleSet(String id) async {
    final db = await database;
    // 先删除该集合下的所有课程
    await db.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
    // 再删除集合本身
    await db.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
  }

  // ============ 课程 CRUD ============

  Future<List<Course>> getCoursesBySet(String setId) async {
    final db = await database;
    final maps = await db
        .query('courses', where: 'scheduleSetId = ?', whereArgs: [setId]);
    return maps.map((map) => Course.fromMap(map)).toList();
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    final maps = await db.query('courses');
    return maps.map((map) => Course.fromMap(map)).toList();
  }

  Future<Course?> getCourse(String id) async {
    final db = await database;
    final maps = await db.query('courses', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Course.fromMap(maps.first);
  }

  Future<void> insertCourse(Course course) async {
    final db = await database;
    await db.insert('courses', course.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCourse(Course course) async {
    final db = await database;
    await db.update('courses', course.toMap(),
        where: 'id = ?', whereArgs: [course.id]);
  }

  Future<void> deleteCourse(String id) async {
    final db = await database;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllCourses() async {
    final db = await database;
    await db.delete('courses');
  }

  Future<void> deleteCoursesBySet(String setId) async {
    final db = await database;
    await db.delete('courses', where: 'scheduleSetId = ?', whereArgs: [setId]);
  }

  Future<void> insertCourses(List<Course> courses) async {
    final db = await database;
    final batch = db.batch();
    for (final course in courses) {
      batch.insert('courses', course.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ============ 时间表 CRUD ============

  Future<List<TimeSlot>> getTimeSlots() async {
    final db = await database;
    final maps = await db.query('time_slots', orderBy: 'period ASC');
    if (maps.isEmpty) return List.from(defaultTimeSlots);
    return maps.map((map) => TimeSlot.fromMap(map)).toList();
  }

  Future<void> updateTimeSlot(TimeSlot slot) async {
    final db = await database;
    await db.update('time_slots', slot.toMap(),
        where: 'period = ?', whereArgs: [slot.period]);
  }

  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    final db = await database;
    await db.delete('time_slots');
    for (final slot in slots) {
      await db.insert('time_slots', slot.toMap());
    }
  }

  // ============ 导出/导入 ============

  Future<String> exportToJson() async {
    final courses = await getCourses();
    final timeSlots = await getTimeSlots();
    final scheduleSets = await getScheduleSets();
    final data = {
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'scheduleSets': scheduleSets.map((s) => s.toMap()).toList(),
      'courses': courses.map((c) => c.toMap()).toList(),
      'timeSlots': timeSlots.map((t) => t.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<Map<String, dynamic>> importFromJson(String jsonStr) async {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final version = data['version'] as String? ?? '1.0';

    final coursesList = (data['courses'] as List)
        .map((e) => Course.fromMap(e as Map<String, dynamic>))
        .toList();
    final timeSlotsList = (data['timeSlots'] as List)
        .map((e) => TimeSlot.fromMap(e as Map<String, dynamic>))
        .toList();

    // 解析课表集（v2.0 格式）
    List<ScheduleSet> scheduleSets = [];
    if (data['scheduleSets'] != null) {
      scheduleSets = (data['scheduleSets'] as List)
          .map((e) => ScheduleSet.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    await deleteAllCourses();

    // 如果没有课表集信息（v1.0 格式），创建默认集
    if (scheduleSets.isEmpty) {
      final defaultSet = ScheduleSet(
        id: 'default',
        name: '我的课表',
        semesterStart: DateTime(2025, 2, 17),
      );
      await insertScheduleSet(defaultSet);
      // 所有课程归入默认集
      for (final course in coursesList) {
        course.scheduleSetId = 'default';
      }
    } else {
      // v2.0 格式：先清空再导入课表集
      final db = await database;
      await db.delete('schedule_sets');
      for (final set in scheduleSets) {
        await insertScheduleSet(set);
      }
    }

    await insertCourses(coursesList);
    if (timeSlotsList.isNotEmpty) {
      await saveTimeSlots(timeSlotsList);
    }

    return {
      'version': version,
      'coursesCount': coursesList.length,
      'timeSlotsCount': timeSlotsList.length,
      'setsCount': scheduleSets.length,
    };
  }
}
