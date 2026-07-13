import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:uuid/uuid.dart';
import '../../models/course.dart';
import '../../utils/course_parser_utils.dart';
import '../../utils/constants.dart';
import 'dart:math';

class WebViewHtmlParser {
  /// 简单的基于 HTML <table> 结构的通用解析器
  static List<Course> parseHtml(String htmlStr) {
    List<Course> courses = [];
    final random = Random();

    // 如果网页包含 iframe，我们在注入 JS 时已经把所有 iframe 的 outerHTML 拼接到一起了
    final document = parse(htmlStr);

    // 1. 尝试寻找强智教务的特征 table
    final tables = document.querySelectorAll('table');
    for (var table in tables) {
      if (table.id == 'kbtable' ||
          table.className.contains('table_border') ||
          table.innerHtml.contains('星期') ||
          table.innerHtml.contains('周')) {
        // 动态判断当前课表有几天（有些学校隐藏周日，只有6天）
        int totalDayCols = 7;
        final ths = table.querySelectorAll('th');
        int dayCount = 0;
        for (var th in ths) {
          if (th.text.contains('星期') ||
              th.text.contains('周一') ||
              th.text.contains('周二') ||
              th.text.contains('周三') ||
              th.text.contains('周四') ||
              th.text.contains('周五') ||
              th.text.contains('周六') ||
              th.text.contains('周日')) {
            dayCount++;
          }
        }
        if (dayCount > 0 && dayCount <= 7) {
          totalDayCols = dayCount;
        }

        final rows = table.querySelectorAll('tr');
        if (rows.isEmpty) continue;

        List<int> rowSpans = List.filled(totalDayCols, 0); // 记录 7 天的跨行情况

        for (int r = 1; r < rows.length; r++) {
          // 跳过表头
          final row = rows[r];
          // 我们只查询 td，忽略 th（比如第一列第二列的“上午”、“第1大节”）
          final cells = row.querySelectorAll('td');
          if (cells.isEmpty) continue;

          // 计算有多少个 td 是不需要当做星期来处理的
          int activeSpans = rowSpans.where((s) => s > 0).length;
          int skipTds = (cells.length + activeSpans) - totalDayCols;
          if (skipTds < 0) skipTds = 0;

          int c = skipTds; // 跳过前面无关的 td（如有）

          for (int col = 0; col < totalDayCols; col++) {
            if (rowSpans[col] > 0) {
              rowSpans[col]--;
              continue;
            }
            if (c < cells.length) {
              final cell = cells[c];
              final rowspan =
                  int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
              rowSpans[col] = rowspan - 1;

              int day = col + 1; // 星期 1~7

              // 强智通常把课程内容放在 kbcontent 里
              final contents = cell.querySelectorAll('.kbcontent');
              var targetNodes = contents.isNotEmpty ? contents : [cell];

              for (var node in targetNodes) {
                // 使用正确的换行提取，防止属性中的 html 代码导致解析错误
                String rawText = _extractTextWithNewlines(node);

                final multipleCourses = rawText.split(RegExp(r'\n*---\n*'));

                for (var singleCourseText in multipleCourses) {
                  final courseBlocks = singleCourseText.split(RegExp(r'\n+'));

                  String name = '';
                  String teacher = '';
                  String timeStr = '';
                  String room = '';

                  List<String> lines = [];
                  for (var text in courseBlocks) {
                    final t = text.trim();
                    if (t.isNotEmpty && t != '&nbsp;') {
                      lines.add(t);
                    }
                  }

                  if (lines.length >= 3) {
                    // 通常结构：
                    // 0: 课程名 (如: 线性代数)
                    // 1: 教师 (如: 熊新生副教授)
                    // 2: 时间 (如: 2-6,8-17(周)[01-02节])
                    // 3: 教室 (如: 厚德楼B501)

                    name = lines[0];

                    for (int i = 1; i < lines.length; i++) {
                      if (lines[i].contains('节]')) {
                        timeStr = lines[i];
                        if (i > 0 && teacher.isEmpty) {
                          teacher = lines[i - 1];
                        }
                        if (i < lines.length - 1) {
                          room = lines[i + 1];
                        }

                        // 直接在这里解析并添加，防止多个时间段被覆盖
                        final weekMatch = RegExp(
                          r'^(.*?)\[',
                        ).firstMatch(timeStr);
                        final periodMatch = RegExp(
                          r'\[(\d+)-(\d+)节\]',
                        ).firstMatch(timeStr);

                        if (periodMatch != null) {
                          final weeksStr = weekMatch != null
                              ? weekMatch.group(1) ?? ''
                              : '';
                          final weeks = CourseParserUtils.parseWeeks(weeksStr);
                          final startPeriod =
                              int.tryParse(periodMatch.group(1) ?? '1') ?? 1;
                          final endPeriod =
                              int.tryParse(periodMatch.group(2) ?? '2') ??
                              startPeriod;
                          final duration = endPeriod - startPeriod + 1;

                          courses.add(
                            Course(
                              id: const Uuid().v4(),
                              name: name,
                              room: room,
                              teacher: teacher,
                              day: day,
                              startPeriod: startPeriod,
                              duration: duration,
                              activeWeeks: weeks.isEmpty
                                  ? List.generate(maxWeekCount, (i) => i + 1)
                                  : weeks,
                              colorValue:
                                  presetColors[random.nextInt(
                                    presetColors.length,
                                  )],
                            ),
                          );
                        }
                      }
                    }
                  }
                }
              }
              c++;
            }
          }
        }
      }
    }

    // 去重
    final uniqueCourses = <Course>[];
    for (var c in courses) {
      if (!uniqueCourses.any(
        (u) =>
            u.name == c.name &&
            u.day == c.day &&
            u.startPeriod == c.startPeriod &&
            u.room == c.room &&
            u.activeWeeks.join(',') == c.activeWeeks.join(','),
      )) {
        uniqueCourses.add(c);
      }
    }

    return uniqueCourses;
  }

  static String _extractTextWithNewlines(Node node) {
    if (node is Text) {
      return node.text;
    } else if (node is Element) {
      if (node.localName == 'br' || node.localName == 'hr') {
        return '\n';
      }
      if (node.localName == 'script' || node.localName == 'style') {
        return '';
      }
      String content = node.nodes
          .map((n) => _extractTextWithNewlines(n))
          .join('');
      if (content.contains('----------')) {
        content = content.replaceAll(RegExp(r'-{10,}'), '\n\n---\n\n');
      }
      return content;
    }
    return '';
  }
}
