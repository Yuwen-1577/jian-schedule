import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/pages/edu_import/edu_import_preview_page.dart';
import 'package:simple_schedule/services/edu_import/edu_import_models.dart';

void main() {
  testWidgets('导入预览显示教师教室与缺失统计', (tester) async {
    const complete = ImportedCourseDraft(
      name: '高等数学',
      teacher: '王老师',
      room: '理A101',
      day: 1,
      startPeriod: 1,
      duration: 2,
      activeWeeks: [1, 2, 3],
      note: '',
      validationIssues: [],
    );
    const missingMetadata = ImportedCourseDraft(
      name: '大学物理',
      teacher: '',
      room: '',
      day: 2,
      startPeriod: 3,
      duration: 2,
      activeWeeks: [1, 3, 5],
      note: '',
      validationIssues: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: EduImportPreviewPage(
          batch: EduImportBatch(
            drafts: [complete, missingMetadata],
            parserVersions: ['强智通用表格版'],
            blockedCrossOriginFrameCount: 0,
          ),
          existingCourses: [],
          scheduleSetName: '测试课表',
        ),
      ),
    );

    expect(find.text('缺教师 1'), findsOneWidget);
    expect(find.text('缺教室 1'), findsOneWidget);
    expect(find.text('教师或教室允许为空；写入前请与教务页面核对缺失项目。'), findsOneWidget);
    expect(find.text('王老师 · 理A101'), findsOneWidget);
  });
}
