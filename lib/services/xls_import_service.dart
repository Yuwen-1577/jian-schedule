import 'dart:io';
import 'package:excel/excel.dart';
import '../models/course.dart';
import '../utils/constants.dart';

class XlsImportService {
  /// 解析 xlsx 文件，返回课程列表
  static Future<List<Course>> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('文件中没有找到工作表');
    }

    final sheet = excel.tables.values.first;
    return _parseSheet(sheet);
  }

  static List<Course> _parseSheet(Sheet sheet) {
    final rows = sheet.rows;
    if (rows.length < 4) {
      throw Exception('工作表数据不足');
    }

    // 找到表头行（含"星期一"或"周一"）
    int headerRow = -1;
    for (int i = 0; i < rows.length && i < 10; i++) {
      final row = rows[i];
      for (int j = 0; j < row.length; j++) {
        final val = _cellToString(row[j]);
        if (val.contains('星期一') || val.contains('周一')) {
          headerRow = i;
          break;
        }
      }
      if (headerRow >= 0) break;
    }

    if (headerRow < 0) {
      throw Exception('未找到课表表头（星期一~星期日）');
    }

    // 确定数据行范围（表头后的 6 行对应 6 大节）
    final dataStartRow = headerRow + 1;
    final dataEndRow =
        (dataStartRow + 6 <= rows.length) ? dataStartRow + 6 : rows.length;

    final courses = <Course>[];
    final colorMap = <String, int>{};
    int colorIndex = 0;

    for (int rowIdx = dataStartRow; rowIdx < dataEndRow; rowIdx++) {
      final slotIndex = rowIdx - dataStartRow; // 0-5
      final startPeriod = slotIndex * 2 + 1; // 1, 3, 5, 7, 9, 11

      final row = rows[rowIdx];
      // 第 0 列是时间标签，第 1-7 列是周一到周日
      for (int col = 1; col <= 7 && col < row.length; col++) {
        final cellText = _cellToString(row[col]);
        if (cellText.trim().isEmpty) continue;

        final dayCourses = _parseCell(cellText, col, startPeriod, colorMap, colorIndex);
        courses.addAll(dayCourses);
        colorIndex += dayCourses.length;
      }
    }

    return courses;
  }

  /// 解析单个单元格，可能包含多门课
  static List<Course> _parseCell(
    String text,
    int day,
    int startPeriod,
    Map<String, int> colorMap,
    int colorIndex,
  ) {
    final courses = <Course>[];
    // 用双换行分割多门课
    final blocks = text.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final course = _parseSingleCourse(trimmed, day, startPeriod, colorMap, colorIndex);
      if (course != null) {
        courses.add(course);
        colorIndex++;
      }
    }

    return courses;
  }

  /// 解析单门课程文本块
  static Course? _parseSingleCourse(
    String text,
    int day,
    int startPeriod,
    Map<String, int> colorMap,
    int colorIndex,
  ) {
    final lines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length < 3) return null;

    // 第一行：课程名
    final name = lines[0];
    // 第二行：教师(职称)
    final teacher = _extractTeacher(lines[1]);
    // 第三行：周次范围
    final weekInfo = _parseWeekRange(lines[2]);
    // 第四行（如果有）：教室
    final room = lines.length >= 4 ? lines[3] : '';

    // 分配颜色
    final color = _getCourseColor(name, colorMap, colorIndex);

    return Course(
      id: '',
      name: name,
      room: room,
      teacher: teacher,
      day: day,
      startPeriod: startPeriod,
      duration: 2,
      startWeek: weekInfo['startWeek']!,
      endWeek: weekInfo['endWeek']!,
      weekType: weekInfo['weekType']!,
      colorValue: color,
    );
  }

  /// 从 "教师(职称)" 中提取教师名
  static String _extractTeacher(String text) {
    // 匹配 "姓名(" 或 "姓名（" 前面的部分
    final match = RegExp(r'^(.+?)[\(（]').firstMatch(text);
    return match?.group(1)?.trim() ?? text.trim();
  }

  /// 解析周次范围
  /// 格式示例：
  ///   "2-6,8-17([周])[01-02节]"
  ///   "11([周])[01-02节]"
  ///   "3,5,7,9([单周])[01-02节]"
  ///   "2-16([双周])[01-02节]"
  ///   "2-10,12-17([周])[01-02节]"
  static Map<String, int> _parseWeekRange(String text) {
    int startWeek = 1;
    int endWeek = 20;
    int weekType = 0; // 0=全周, 1=单周, 2=双周

    // 检测单双周
    if (text.contains('单周') || text.contains('单')) {
      weekType = 1;
    } else if (text.contains('双周') || text.contains('双')) {
      weekType = 2;
    }

    // 提取周次数字部分：在 "([周])" 或 "([单周])" 之前的内容
    final weekPartMatch = RegExp(r'^([\d,\-\s]+)').firstMatch(text.trim());
    if (weekPartMatch != null) {
      final weekPart = weekPartMatch.group(1)!.trim();
      final numbers = _extractWeekNumbers(weekPart);
      if (numbers.isNotEmpty) {
        numbers.sort();
        startWeek = numbers.first;
        endWeek = numbers.last;
      }
    }

    return {
      'startWeek': startWeek,
      'endWeek': endWeek,
      'weekType': weekType,
    };
  }

  /// 从 "2-6,8-17" 或 "3,5,7,9" 或 "11" 提取所有周次数字
  static List<int> _extractWeekNumbers(String text) {
    final numbers = <int>[];
    // 分割逗号
    final parts = text.split(RegExp(r'[,\s]+'));
    for (final part in parts) {
      if (part.contains('-')) {
        // 范围 "2-6"
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null) {
            for (int i = start; i <= end; i++) {
              numbers.add(i);
            }
          }
        }
      } else {
        // 单个数字 "11"
        final n = int.tryParse(part.trim());
        if (n != null) numbers.add(n);
      }
    }
    return numbers;
  }

  /// 为同名课程分配相同颜色
  static int _getCourseColor(
      String name, Map<String, int> colorMap, int fallbackIndex) {
    if (colorMap.containsKey(name)) {
      return colorMap[name]!;
    }
    final color = presetColors[fallbackIndex % presetColors.length];
    colorMap[name] = color;
    return color;
  }

  /// 将单元格值转为字符串
  static String _cellToString(dynamic cell) {
    if (cell == null) return '';
    // excel 包的 Data 类型有 value 属性
    try {
      return cell.value?.toString() ?? '';
    } catch (_) {
      return cell.toString();
    }
  }
}
