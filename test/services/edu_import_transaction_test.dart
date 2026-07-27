import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';
import 'package:simple_schedule/services/edu_import/edu_import_transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        room TEXT NOT NULL,
        teacher TEXT NOT NULL,
        day INTEGER NOT NULL,
        startPeriod INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        activeWeeks TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        note TEXT NOT NULL,
        scheduleSetId TEXT NOT NULL,
        reminderMinutesBefore INTEGER NOT NULL
      )
    ''');
  });

  tearDown(() => database.close());

  Course course(String id, String name, String setId) {
    return Course(
      id: id,
      name: name,
      day: 1,
      startPeriod: 1,
      activeWeeks: const [1, 2],
      scheduleSetId: setId,
    );
  }

  test('替换只影响当前课表集', () async {
    await database.insert('courses', course('old', '旧课程', 'current').toMap());
    await database.insert('courses', course('other', '其他课表', 'other').toMap());

    await EduImportTransaction.replaceCoursesForSet(
      database,
      scheduleSetId: 'current',
      courses: [course('new', '新课程', 'current')],
    );

    final current = await database.query(
      'courses',
      where: 'scheduleSetId = ?',
      whereArgs: ['current'],
    );
    final other = await database.query(
      'courses',
      where: 'scheduleSetId = ?',
      whereArgs: ['other'],
    );
    expect(current.map((row) => row['name']), ['新课程']);
    expect(other.map((row) => row['name']), ['其他课表']);
  });

  test('替换中途失败会回滚删除和写入', () async {
    await database.insert('courses', course('old', '旧课程', 'current').toMap());
    final duplicateId = course('same-id', '课程一', 'current');
    final conflicting = course('same-id', '课程二', 'current');

    await expectLater(
      EduImportTransaction.replaceCoursesForSet(
        database,
        scheduleSetId: 'current',
        courses: [duplicateId, conflicting],
      ),
      throwsA(isA<DatabaseException>()),
    );

    final current = await database.query(
      'courses',
      where: 'scheduleSetId = ?',
      whereArgs: ['current'],
    );
    expect(current, hasLength(1));
    expect(current.single['name'], '旧课程');
  });
}
