import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';
import 'package:simple_schedule/services/edu_import/edu_import_commit_service.dart';
import 'package:simple_schedule/services/edu_import/edu_import_models.dart';

void main() {
  ImportedCourseDraft draft({
    String name = '数据库',
    String room = 'A101',
    List<int> weeks = const [1, 2],
  }) {
    return ImportedCourseDraft(
      name: name,
      teacher: '陈老师',
      room: room,
      day: 1,
      startPeriod: 1,
      duration: 2,
      activeWeeks: weeks,
      note: '',
      validationIssues: const [],
    );
  }

  Course existing(ImportedCourseDraft source) {
    return source.toCourse(scheduleSetId: 'current');
  }

  test('仅新增会稳定跳过现有重复课程，重叠课程仍可导入', () {
    final duplicate = draft();
    final overlapping = draft(name: '计算机网络');
    final batch = EduImportBatch(
      drafts: [duplicate, overlapping],
      parserVersions: const ['fixture'],
      blockedCrossOriginFrameCount: 0,
    );

    final plan = EduImportCommitService.createPlan(
      batch: batch,
      scheduleSetId: 'current',
      existingCourses: [existing(duplicate)],
      mode: ImportMode.append,
    );

    expect(plan.courses, hasLength(1));
    expect(plan.courses.single.name, '计算机网络');
    expect(plan.skippedCount, 1);
  });

  test('替换模式只对批次内部去重，不受当前课程影响', () {
    final duplicate = draft();
    final batch = EduImportBatch(
      drafts: [duplicate, duplicate],
      parserVersions: const ['fixture'],
      blockedCrossOriginFrameCount: 0,
    );

    final plan = EduImportCommitService.createPlan(
      batch: batch,
      scheduleSetId: 'current',
      existingCourses: [existing(duplicate)],
      mode: ImportMode.replace,
    );

    expect(plan.courses, hasLength(1));
    expect(plan.skippedCount, 1);
    expect(plan.courses.single.scheduleSetId, 'current');
  });

  test('课程颜色按课程名稳定分配', () {
    final first = draft(name: '操作系统', room: 'A101');
    final second = draft(name: '操作系统', room: 'B202');

    expect(
      first.toCourse(scheduleSetId: 'one').colorValue,
      second.toCourse(scheduleSetId: 'two').colorValue,
    );
  });
}
