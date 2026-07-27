import '../../models/course.dart';
import 'edu_import_models.dart';

class EduImportPlan {
  const EduImportPlan({
    required this.courses,
    required this.skippedCount,
    required this.invalidCount,
  });

  final List<Course> courses;
  final int skippedCount;
  final int invalidCount;
}

class EduImportCommitService {
  static EduImportPlan createPlan({
    required EduImportBatch batch,
    required String scheduleSetId,
    required Iterable<Course> existingCourses,
    required ImportMode mode,
  }) {
    final knownFingerprints = mode == ImportMode.append
        ? existingCourses.map(courseFingerprint).toSet()
        : <String>{};
    final courses = <Course>[];
    var skipped = 0;

    for (final draft in batch.validDrafts) {
      if (!knownFingerprints.add(draft.fingerprint)) {
        skipped++;
        continue;
      }
      courses.add(draft.toCourse(scheduleSetId: scheduleSetId));
    }

    return EduImportPlan(
      courses: courses,
      skippedCount: skipped,
      invalidCount: batch.invalidDrafts.length,
    );
  }

  static int duplicateCount({
    required EduImportBatch batch,
    required Iterable<Course> existingCourses,
  }) {
    final known = existingCourses.map(courseFingerprint).toSet();
    final withinBatch = <String>{};
    var duplicates = 0;
    for (final draft in batch.validDrafts) {
      if (!withinBatch.add(draft.fingerprint) ||
          known.contains(draft.fingerprint)) {
        duplicates++;
      }
    }
    return duplicates;
  }

  static String courseFingerprint(Course course) {
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
}
