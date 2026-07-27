import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/services/edu_import/edu_import_models.dart';
import 'package:simple_schedule/services/edu_import/strong_wisdom_parser.dart';

void main() {
  EduImportBatch parseFixture(String html) {
    return StrongWisdomParser.parse(
      CapturedPageBundle(
        documents: [CapturedPageDocument(html: html, frameDepth: 0)],
      ),
    );
  }

  test('解析 2024 工具提示版：周日首列、多课程、单双周', () {
    final batch = parseFixture('''
      <table>
        <thead><tr><th>节次</th><th>周日</th><th>周一</th></tr></thead>
        <tbody><tr>
          <td>1</td>
          <td name="kbDataTd">
            <div class="qz-tooltipContent-item"
              data-name="设计史" data-teacher="林老师"
              data-room="艺A101" data-weeks="2-10周双周"
              data-period="01-02节"></div>
            <div class="qz-tooltipContent-item"
              data-name="摄影基础" data-weeks="1-9周单周"
              data-period="03-04节"></div>
          </td>
          <td name="kbDataTd"></td>
        </tr></tbody>
      </table>
    ''');

    expect(batch.parserVersions, [StrongWisdomParser.version2024]);
    expect(batch.validDrafts, hasLength(2));
    expect(batch.validDrafts.first.day, 7);
    expect(batch.validDrafts.first.activeWeeks, [2, 4, 6, 8, 10]);
    expect(batch.validDrafts.last.activeWeeks, [1, 3, 5, 7, 9]);
  });

  test('解析 2017 Element UI 版：不连续周次与缺失教师教室', () {
    final batch = parseFixture('''
      <table class="el-table__header">
        <tr><th>节次</th><th>周一</th><th>周二</th></tr>
      </table>
      <table class="el-table__body">
        <tr>
          <td>1</td>
          <td></td>
          <td>
            <div class="course-item" data-name="离散数学"
              data-weeks="1,3,5-7周" data-period="第3-4节"></div>
          </td>
        </tr>
      </table>
    ''');

    expect(batch.parserVersions, [StrongWisdomParser.version2017]);
    expect(batch.validDrafts.single.day, 2);
    expect(batch.validDrafts.single.activeWeeks, [1, 3, 5, 6, 7]);
    expect(batch.validDrafts.single.teacher, isEmpty);
    expect(batch.validDrafts.single.room, isEmpty);
  });

  test('解析通用 kbcontent 表格：跨行单元格仍保留课程节次', () {
    final batch = parseFixture('''
      <table id="kbtable">
        <thead><tr><th>节次</th><th>周一</th><th>周二</th></tr></thead>
        <tbody>
          <tr>
            <td rowspan="2">1-2</td>
            <td rowspan="2">
              <div class="kbcontent" data-name="高等数学"
                data-teacher="周老师" data-room="理B203"
                data-weeks="1-16周" data-period="[01-02节]"></div>
            </td>
            <td></td>
          </tr>
          <tr><td></td></tr>
        </tbody>
      </table>
    ''');

    expect(batch.parserVersions, [StrongWisdomParser.versionCommon]);
    final course = batch.validDrafts.single;
    expect(course.day, 1);
    expect(course.startPeriod, 1);
    expect(course.duration, 2);
    expect(course.activeWeeks, List.generate(16, (index) => index + 1));
  });

  test('解析旧版 title/br 结构', () {
    final batch = parseFixture('''
      <table id="kb">
        <tr><th>节次</th><th>周一</th><th>周二</th><th>周三</th></tr>
        <tr>
          <td>5</td><td></td><td></td>
          <td><a title="大学写作<br>教师：许老师<br>教室：文C305<br>3-12周 [05-06节]"></a></td>
        </tr>
      </table>
    ''');

    expect(batch.parserVersions, [StrongWisdomParser.versionLegacy]);
    final course = batch.validDrafts.single;
    expect(course.name, '大学写作');
    expect(course.day, 3);
    expect(course.teacher, '许老师');
    expect(course.room, '文C305');
  });

  test('错误周次列为无效，不会替换成全部周', () {
    final batch = parseFixture('''
      <table class="timetable">
        <tr><th>节次</th><th>周一</th></tr>
        <tr><td>1</td><td>
          <div class="kbcontent" data-name="待定课程"
            data-weeks="周次待定" data-period="1-2节"></div>
        </td></tr>
      </table>
    ''');

    expect(batch.validDrafts, isEmpty);
    expect(batch.invalidDrafts, hasLength(1));
    expect(batch.invalidDrafts.single.activeWeeks, isEmpty);
    expect(batch.invalidDrafts.single.validationIssues, contains('无法识别有效周次'));
  });

  test('跨文档重复课程去重并保留跨域框架计数', () {
    const html = '''
      <table id="kbtable">
        <tr><th>节次</th><th>周一</th></tr>
        <tr><td>1</td><td><div class="kbcontent"
          data-name="线性代数" data-weeks="1-8周"
          data-period="1-2节"></div></td></tr>
      </table>
    ''';
    final batch = StrongWisdomParser.parse(
      const CapturedPageBundle(
        documents: [
          CapturedPageDocument(html: html, frameDepth: 0),
          CapturedPageDocument(html: html, frameDepth: 1),
        ],
        blockedCrossOriginFrameCount: 2,
      ),
    );

    expect(batch.validDrafts, hasLength(1));
    expect(batch.blockedCrossOriginFrameCount, 2);
  });
}
