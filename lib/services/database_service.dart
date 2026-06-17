import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/course.dart';
import '../models/schedule_set.dart';
import '../models/time_slot.dart';
import '../utils/constants.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database>? _initDbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _initDbFuture ??= _initDatabase();
    _database = await _initDbFuture!;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'schedule.db');
    return await openDatabase(
      path,
      version: 4,
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
        activeWeeks TEXT DEFAULT '[]',
        colorValue INTEGER DEFAULT 0xFF4CAF50,
        note TEXT DEFAULT '',
        scheduleSetId TEXT DEFAULT '',
        reminderMinutesBefore INTEGER DEFAULT 15,
        FOREIGN KEY (scheduleSetId) REFERENCES schedule_sets(id) ON DELETE CASCADE
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
      'id': defaultSetId,
      'name': '我的课表',
      'semesterStart': defaultSemesterStart.toIso8601String(),
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
        'id': defaultSetId,
        'name': '我的课表',
        'semesterStart': defaultSemesterStart.toIso8601String(),
        'sortOrder': 0,
      });
      // courses 表新增 scheduleSetId 列
      await db.execute(
        "ALTER TABLE courses ADD COLUMN scheduleSetId TEXT DEFAULT ''",
      );
      // 现有课程归入默认集
      await db.update('courses', {'scheduleSetId': defaultSetId});
    }
    if (oldVersion < 3) {
      // v3: 课程提醒字段
      await db.execute(
        "ALTER TABLE courses ADD COLUMN reminderMinutesBefore INTEGER DEFAULT 15",
      );
    }
    if (oldVersion < 4) {
      // v4: 自定义上课周数
      await db.execute(
        "ALTER TABLE courses ADD COLUMN activeWeeks TEXT DEFAULT '[]'",
      );
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
    final maps = await db.query(
      'schedule_sets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ScheduleSet.fromMap(maps.first);
  }

  Future<void> insertScheduleSet(ScheduleSet set) async {
    final db = await database;
    await db.insert(
      'schedule_sets',
      set.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateScheduleSet(ScheduleSet set) async {
    final db = await database;
    await db.update(
      'schedule_sets',
      set.toMap(),
      where: 'id = ?',
      whereArgs: [set.id],
    );
  }

  Future<void> deleteScheduleSet(String id) async {
    try {
      final db = await database;
      await db.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
      await db.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      throw Exception('删除课表集失败: $e');
    }
  }

  // ============ 课程 CRUD ============

  Future<List<Course>> getCoursesBySet(String setId) async {
    final db = await database;
    final maps = await db.query(
      'courses',
      where: 'scheduleSetId = ?',
      whereArgs: [setId],
    );
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
    await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCourse(Course course) async {
    try {
      final db = await database;
      await db.update(
        'courses',
        course.toMap(),
        where: 'id = ?',
        whereArgs: [course.id],
      );
    } on DatabaseException catch (e) {
      throw Exception('更新课程失败: $e');
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      final db = await database;
      await db.delete('courses', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      throw Exception('删除课程失败: $e');
    }
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
      batch.insert(
        'courses',
        course.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ============ 时间表 CRUD ============

  Future<List<TimeSlot>> getTimeSlots() async {
    try {
      final db = await database;
      final maps = await db.query('time_slots', orderBy: 'period ASC');
      if (maps.isEmpty) return List.from(defaultTimeSlots);
      return maps.map((map) => TimeSlot.fromMap(map)).toList();
    } on DatabaseException catch (e) {
      throw Exception('获取时间表失败: $e');
    }
  }

  Future<void> updateTimeSlot(TimeSlot slot) async {
    final db = await database;
    await db.update(
      'time_slots',
      slot.toMap(),
      where: 'period = ?',
      whereArgs: [slot.period],
    );
  }

  Future<void> saveTimeSlots(List<TimeSlot> slots) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('time_slots');
      final batch = txn.batch();
      for (final slot in slots) {
        batch.insert('time_slots', slot.toMap());
      }
      await batch.commit(noResult: true);
    });
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
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final version = data['version'] as String? ?? '1.0';

      final coursesRaw = data['courses'];
      if (coursesRaw is! List) {
        throw Exception('JSON 格式错误: courses 字段必须是数组');
      }
      final coursesList = coursesRaw
          .map((e) => Course.fromMap(e as Map<String, dynamic>))
          .toList();

      final timeSlotsRaw = data['timeSlots'];
      final timeSlotsList = timeSlotsRaw is List
          ? timeSlotsRaw
                .map((e) => TimeSlot.fromMap(e as Map<String, dynamic>))
                .toList()
          : <TimeSlot>[];

      List<ScheduleSet> scheduleSets = [];
      final setsRaw = data['scheduleSets'];
      if (setsRaw is List && setsRaw.isNotEmpty) {
        scheduleSets = setsRaw
            .map((e) => ScheduleSet.fromMap(e as Map<String, dynamic>))
            .toList();
      }

      final db = await database;
      await db.transaction((txn) async {
        // 清空旧数据
        await txn.delete('courses');
        await txn.delete('schedule_sets');

        if (scheduleSets.isEmpty) {
          // v1.0 格式：创建默认集
          final defaultSet = ScheduleSet(
            id: defaultSetId,
            name: '我的课表',
            semesterStart: defaultSemesterStart,
          );
          await txn.insert(
            'schedule_sets',
            defaultSet.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (final course in coursesList) {
            course.scheduleSetId = defaultSetId;
          }
        } else {
          // v2.0 格式：导入课表集
          for (final set in scheduleSets) {
            await txn.insert(
              'schedule_sets',
              set.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        // 批量插入课程
        for (final course in coursesList) {
          await txn.insert(
            'courses',
            course.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // 导入时间表
        if (timeSlotsList.isNotEmpty) {
          await txn.delete('time_slots');
          for (final slot in timeSlotsList) {
            await txn.insert('time_slots', slot.toMap());
          }
        }
      });

      return {
        'version': version,
        'coursesCount': coursesList.length,
        'timeSlotsCount': timeSlotsList.length,
        'setsCount': scheduleSets.length,
      };
    } on FormatException catch (e) {
      throw Exception('JSON 格式错误: $e');
    } on DatabaseException catch (e) {
      throw Exception('数据库导入失败: $e');
    } catch (e) {
      throw Exception('导入失败: $e');
    }
  }
}
