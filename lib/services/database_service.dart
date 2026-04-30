import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/course.dart';
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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
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
        note TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE time_slots (
        period INTEGER PRIMARY KEY,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL
      )
    ''');
    // 插入默认时间表
    for (final slot in defaultTimeSlots) {
      await db.insert('time_slots', slot.toMap());
    }
  }

  // ============ 课程 CRUD ============

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
    final data = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'courses': courses.map((c) => c.toMap()).toList(),
      'timeSlots': timeSlots.map((t) => t.toMap()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<Map<String, dynamic>> importFromJson(String jsonStr) async {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final coursesList = (data['courses'] as List)
        .map((e) => Course.fromMap(e as Map<String, dynamic>))
        .toList();
    final timeSlotsList = (data['timeSlots'] as List)
        .map((e) => TimeSlot.fromMap(e as Map<String, dynamic>))
        .toList();

    await deleteAllCourses();
    await insertCourses(coursesList);
    if (timeSlotsList.isNotEmpty) {
      await saveTimeSlots(timeSlotsList);
    }

    return {
      'coursesCount': coursesList.length,
      'timeSlotsCount': timeSlotsList.length,
    };
  }
}
