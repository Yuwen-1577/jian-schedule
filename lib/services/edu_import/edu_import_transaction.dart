import 'package:sqflite/sqflite.dart';

import '../../models/course.dart';

class EduImportTransaction {
  static Future<void> replaceCoursesForSet(
    Database database, {
    required String scheduleSetId,
    required List<Course> courses,
  }) async {
    await database.transaction((transaction) async {
      await transaction.delete(
        'courses',
        where: 'scheduleSetId = ?',
        whereArgs: [scheduleSetId],
      );
      for (final course in courses) {
        await transaction.insert(
          'courses',
          course.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }
}
