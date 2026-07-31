import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/services/edu_import/edu_import_diagnostics.dart';
import 'package:simple_schedule/services/edu_import/edu_import_models.dart';
import 'package:simple_schedule/services/edu_import/strong_wisdom_parser.dart';

void main() {
  const sensitiveHtml = '''
    <!doctype html>
    <html>
      <head>
        <script>window.secretCookie = "cookie_super_secret";</script>
        <style>.private { background: url("https://jwgl.example.edu.cn/a"); }</style>
      </head>
      <body id="student-20261234" class="timetable safe-layout">
        <form action="https://jwgl.example.edu.cn/login">
          <input name="studentAccount" value="20261234">
          <input type="password" value="P@ssw0rd!">
        </form>
        <table id="kbtable">
          <tr><th>节次</th><th>周一</th></tr>
          <tr>
            <td>1-2节</td>
            <td name="kbDataTd">
              <div class="kbcontent course-item-20261234"
                data-name="隐私课程"
                data-teacher="王敏感老师"
                data-room="秘密楼A101"
                data-weeks="1-8周"
                data-period="1-2节"
                data-secret="opaque-value">
                隐私课程<br>
                <span title="教师">王敏感老师</span><br>
                <a href="https://jwgl.example.edu.cn/student/20261234"
                   onclick="sendSecret()">学生虚构甲</a>
              </div>
            </td>
          </tr>
        </table>
      </body>
    </html>
  ''';

  EduImportParseResult parseDetailed(String html, {int blockedFrameCount = 0}) {
    return StrongWisdomParser.parseDetailed(
      CapturedPageBundle(
        documents: [CapturedPageDocument(html: html, frameDepth: 0)],
        blockedCrossOriginFrameCount: blockedFrameCount,
      ),
    );
  }

  test('详细解析保持原课程结果并记录四条规则尝试', () {
    final result = parseDetailed(sensitiveHtml, blockedFrameCount: 2);
    final legacyResult = StrongWisdomParser.parse(
      const CapturedPageBundle(
        documents: [CapturedPageDocument(html: sensitiveHtml, frameDepth: 0)],
        blockedCrossOriginFrameCount: 2,
      ),
    );

    expect(
      result.batch.drafts.map((draft) => draft.fingerprint),
      legacyResult.drafts.map((draft) => draft.fingerprint),
    );
    expect(result.diagnostics.ruleAttempts, hasLength(4));
    expect(
      result.diagnostics.ruleAttempts.where((attempt) => attempt.selected),
      hasLength(1),
    );
    expect(result.diagnostics.blockedCrossOriginFrameCount, 2);
  });

  test('安全结构报告不包含网页文本、属性值、网址或原始 HTML', () {
    final report = parseDetailed(sensitiveHtml).diagnostics.toStructureJson();
    final decoded = jsonDecode(report) as Map<String, dynamic>;

    expect(decoded['reportType'], 'structure');
    expect(decoded['documentCount'], 1);
    expect(report, isNot(contains('隐私课程')));
    expect(report, isNot(contains('王敏感老师')));
    expect(report, isNot(contains('秘密楼A101')));
    expect(report, isNot(contains('虚构甲')));
    expect(report, isNot(contains('20261234')));
    expect(report, isNot(contains('jwgl.example.edu.cn')));
    expect(report, isNot(contains('P@ssw0rd!')));
    expect(report, isNot(contains('cookie_super_secret')));
    expect(report, isNot(contains('<table')));
    expect(report, contains('tagHistogram'));
    expect(report, contains('attributeNameHistogram'));
  });

  test('深度脱敏页面保留静态 DOM 特征并剥离全部敏感值', () {
    final report = parseDetailed(sensitiveHtml).diagnostics.toSanitizedHtml();

    expect(report, contains('timetable'));
    expect(report, contains('safe-layout'));
    expect(report, contains('kbcontent'));
    expect(report, contains('kbtable'));
    expect(report, contains('data-name'));
    expect(report, isNot(contains('course-item-20261234')));
    expect(report, isNot(contains('隐私课程')));
    expect(report, isNot(contains('王敏感老师')));
    expect(report, isNot(contains('秘密楼A101')));
    expect(report, isNot(contains('虚构甲')));
    expect(report, isNot(contains('20261234')));
    expect(report, isNot(contains('jwgl.example.edu.cn')));
    expect(report, isNot(contains('P@ssw0rd!')));
    expect(report, isNot(contains('cookie_super_secret')));
    expect(report, isNot(contains('sendSecret')));
    expect(report, isNot(contains('<script>')));
    expect(report, contains('课程名称'));
    expect(report, contains('已脱敏'));
  });

  test('多文档保留框架深度并在超过两万元素时标记截断', () {
    final spans = List.filled(
      EduImportDiagnosticBuilder.maxElementCount + 5,
      '<span>敏感文本</span>',
    ).join();
    final result = StrongWisdomParser.parseDetailed(
      CapturedPageBundle(
        documents: [
          const CapturedPageDocument(
            html: '<html><body></body></html>',
            frameDepth: 0,
          ),
          CapturedPageDocument(
            html: '<html><body>$spans</body></html>',
            frameDepth: 1,
          ),
        ],
        blockedCrossOriginFrameCount: 3,
      ),
    );

    expect(result.diagnostics.documents, hasLength(2));
    expect(result.diagnostics.documents.last.frameDepth, 1);
    expect(result.diagnostics.truncated, isTrue);
    expect(result.diagnostics.documents.last.truncated, isTrue);
    expect(
      result.diagnostics.documents.fold<int>(
        0,
        (total, document) => total + document.reportedElementCount,
      ),
      lessThanOrEqualTo(EduImportDiagnosticBuilder.maxElementCount),
    );
    expect(result.diagnostics.toStructureJson(), contains('"truncated": true'));
    expect(result.diagnostics.toSanitizedHtml(), isNot(contains('敏感文本')));
  });

  test('空页面仍能生成不含原始页面的诊断报告', () {
    final result = parseDetailed('');

    expect(result.batch.drafts, isEmpty);
    expect(result.diagnostics.documents, hasLength(1));
    expect(result.diagnostics.toStructureJson(), contains('"draftCount": 0'));
  });
}
