import 'package:uuid/uuid.dart';

import '../../models/course.dart';
import '../../utils/constants.dart';

class CapturedPageDocument {
  const CapturedPageDocument({required this.html, required this.frameDepth});

  final String html;
  final int frameDepth;
}

class CapturedPageBundle {
  const CapturedPageBundle({
    required this.documents,
    this.blockedCrossOriginFrameCount = 0,
  });

  final List<CapturedPageDocument> documents;
  final int blockedCrossOriginFrameCount;
}

enum ImportMode { append, replace }

class ImportCommitResult {
  const ImportCommitResult({
    required this.insertedCount,
    required this.skippedCount,
    required this.invalidCount,
  });

  final int insertedCount;
  final int skippedCount;
  final int invalidCount;
}

class ImportedCourseDraft {
  const ImportedCourseDraft({
    required this.name,
    required this.teacher,
    required this.room,
    required this.day,
    required this.startPeriod,
    required this.duration,
    required this.activeWeeks,
    required this.note,
    required this.validationIssues,
  });

  final String name;
  final String teacher;
  final String room;
  final int? day;
  final int? startPeriod;
  final int? duration;
  final List<int> activeWeeks;
  final String note;
  final List<String> validationIssues;

  bool get isValid => validationIssues.isEmpty;

  String get fingerprint {
    final weeks = List<int>.from(activeWeeks)..sort();
    return [
      name.trim(),
      teacher.trim(),
      room.trim(),
      day,
      startPeriod,
      duration,
      weeks.join(','),
    ].join('|');
  }

  Course toCourse({required String scheduleSetId}) {
    if (!isValid || day == null || startPeriod == null || duration == null) {
      throw StateError('无效的课程草稿不能写入课表');
    }
    return Course(
      id: const Uuid().v4(),
      name: name.trim(),
      teacher: teacher.trim(),
      room: room.trim(),
      day: day!,
      startPeriod: startPeriod!,
      duration: duration!,
      activeWeeks: List<int>.from(activeWeeks)..sort(),
      colorValue: stableCourseColor(name),
      note: note.trim(),
      scheduleSetId: scheduleSetId,
    );
  }
}

class EduImportBatch {
  const EduImportBatch({
    required this.drafts,
    required this.parserVersions,
    required this.blockedCrossOriginFrameCount,
  });

  final List<ImportedCourseDraft> drafts;
  final List<String> parserVersions;
  final int blockedCrossOriginFrameCount;

  List<ImportedCourseDraft> get validDrafts =>
      drafts.where((draft) => draft.isValid).toList(growable: false);

  List<ImportedCourseDraft> get invalidDrafts =>
      drafts.where((draft) => !draft.isValid).toList(growable: false);
}

int stableCourseColor(String courseName) {
  final normalized = courseName.trim().toLowerCase();
  return presetColors[stableId(normalized) % presetColors.length];
}
