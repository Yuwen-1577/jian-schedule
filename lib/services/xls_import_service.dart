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
    if (rows.length < 3) {
      throw Exception('工作表数据不足');
    }

    // 构建二维字符串网格
    final grid = <List<String>>[];
    for (final row in rows) {
      final cells = <String>[];
      for (final cell in row) {
        cells.add(_cellToString(cell));
      }
      grid.add(cells);
    }

    // 1. 找到所有包含星期关键词的单元格位置
    final weekdayPositions = <_WeekdayPos>[];
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final weekday = _detectWeekday(grid[r][c]);
        if (weekday > 0) {
          weekdayPositions.add(_WeekdayPos(r, c, weekday));
        }
      }
    }

    if (weekdayPositions.isEmpty) {
      throw Exception('未找到课表表头（星期一~星期日）');
    }

    // 2. 确定表头行和列映射
    // 按行分组，找出行数最多的那一行作为表头行
    final rowGroups = <int, List<_WeekdayPos>>{};
    for (final pos in weekdayPositions) {
      rowGroups.putIfAbsent(pos.row, () => []);
      rowGroups[pos.row]!.add(pos);
    }

    // 选择包含最多星期关键词的行作为表头
    int headerRow = rowGroups.entries
        .reduce((a, b) => a.value.length >= b.value.length ? a : b)
        .key;

    // 构建 weekday -> column 的映射
    final dayColMap = <int, int>{}; // weekday(1-7) -> column index
    for (final pos in rowGroups[headerRow]!) {
      // 如果同一星期有多个列，取第一个
      dayColMap.putIfAbsent(pos.weekday, () => pos.col);
    }

    // 3. 确定数据起始行和结束行
    // 数据从表头行的下一行开始
    int dataStartRow = headerRow + 1;

    // 数据结束行：从 dataStartRow 开始向下扫描，
    // 遇到新的星期关键词行（可能是另一个课表块）或连续空行则停止
    int dataEndRow = grid.length;
    for (int r = dataStartRow; r < grid.length; r++) {
      // 检查是否是新的表头行（包含多个星期关键词）
      int weekdayCount = 0;
      for (int c = 0; c < grid[r].length; c++) {
        if (_detectWeekday(grid[r][c]) > 0) weekdayCount++;
      }
      if (weekdayCount >= 3) {
        dataEndRow = r;
        break;
      }

      // 检查是否是连续空行
      bool allEmpty = true;
      for (final col in dayColMap.values) {
        if (col < grid[r].length && grid[r][col].trim().isNotEmpty) {
          allEmpty = false;
          break;
        }
      }
      // 如果连续2行全空则停止（允许偶尔空行）
      if (allEmpty && r + 1 < grid.length) {
        bool nextAllEmpty = true;
        for (final col in dayColMap.values) {
          if (col < grid[r + 1].length &&
              grid[r + 1][col].trim().isNotEmpty) {
            nextAllEmpty = false;
            break;
          }
        }
        if (nextAllEmpty) {
          dataEndRow = r;
          break;
        }
      }
    }

    // 4. 解析课程
    final courses = <Course>[];
    final colorMap = <String, int>{};
    int colorIndex = 0;

    for (int r = dataStartRow; r < dataEndRow; r++) {
      // 计算当前行对应的节次
      final slotIndex = r - dataStartRow;
      final startPeriod = slotIndex * 2 + 1; // 1, 3, 5, 7, 9, 11

      for (final entry in dayColMap.entries) {
        final day = entry.key;
        final col = entry.value;

        if (col >= grid[r].length) continue;
        final cellText = grid[r][col].trim();
        if (cellText.isEmpty) continue;

        final dayCourses = _parseCell(
            cellText, day, startPeriod, colorMap, colorIndex);
        courses.addAll(dayCourses);
        colorIndex += dayCourses.length;
      }
    }

    return courses;
  }

  /// 检测文本中是否包含星期关键词，返回 weekday (1-7) 或 0
  static int _detectWeekday(String text) {
    final t = text.trim();
    // 完整匹配优先
    if (t == '星期一' || t == '周一' || t == '一' || t == 'Mon' || t == 'Monday')
      return 1;
    if (t == '星期二' || t == '周二' || t == '二' || t == 'Tue' || t == 'Tuesday')
      return 2;
    if (t == '星期三' || t == '周三' || t == '三' || t == 'Wed' || t == 'Wednesday')
      return 3;
    if (t == '星期四' || t == '周四' || t == '四' || t == 'Thu' || t == 'Thursday')
      return 4;
    if (t == '星期五' || t == '周五' || t == '五' || t == 'Fri' || t == 'Friday')
      return 5;
    if (t == '星期六' || t == '周六' || t == '六' || t == 'Sat' || t == 'Saturday')
      return 6;
    if (t == '星期日' || t == '星期天' || t == '周日' || t == '周天' || t == '日' || t == '天' || t == 'Sun' || t == 'Sunday')
      return 7;

    // 包含匹配（处理 "第1节 星期一" 这类情况）
    if (t.contains('星期一') || t.contains('周一')) return 1;
    if (t.contains('星期二') || t.contains('周二')) return 2;
    if (t.contains('星期三') || t.contains('周三')) return 3;
    if (t.contains('星期四') || t.contains('周四')) return 4;
    if (t.contains('星期五') || t.contains('周五')) return 5;
    if (t.contains('星期六') || t.contains('周六')) return 6;
    if (t.contains('星期日') || t.contains('星期天') || t.contains('周日'))
      return 7;

    return 0;
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

      final course =
          _parseSingleCourse(trimmed, day, startPeriod, colorMap, colorIndex);
      if (course != null) {
        courses.add(course);
        colorIndex++;
      }
    }

    // 如果双换行分割没结果，尝试单换行分割整个文本
    if (courses.isEmpty) {
      final course =
          _parseSingleCourse(text, day, startPeriod, colorMap, colorIndex);
      if (course != null) {
        courses.add(course);
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
    if (lines.isEmpty) return null;

    // 智能识别各行内容
    String name = '';
    String teacher = '';
    String room = '';
    int wStart = 1, wEnd = 20, wType = 0;

    // 第一行通常是课程名
    name = lines[0];

    // 如果只有一行，尝试从里面提取信息
    if (lines.length == 1) {
      final info = _extractFromSingleLine(lines[0]);
      if (info['name']!.isNotEmpty) name = info['name']!;
      if (info['teacher']!.isNotEmpty) teacher = info['teacher']!;
      if (info['room']!.isNotEmpty) room = info['room']!;
      return Course(
        id: '',
        name: name,
        room: room,
        teacher: teacher,
        day: day,
        startPeriod: startPeriod,
        duration: 2,
        startWeek: wStart,
        endWeek: wEnd,
        weekType: wType,
        colorValue: _getCourseColor(name, colorMap, colorIndex),
      );
    }

    // 多行：逐行分析
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];

      // 跳过节次信息行（如 "第1-2节"、"01-02节"）
      if (RegExp(r'^[\[\(（【]?\d{1,2}[\-~—]\d{1,2}节').hasMatch(line)) continue;
      if (RegExp(r'^第\d').hasMatch(line) && line.contains('节')) continue;

      // 检测周次信息
      final weekInfo = _tryParseWeekLine(line);
      if (weekInfo != null) {
        wStart = weekInfo['startWeek']!;
        wEnd = weekInfo['endWeek']!;
        wType = weekInfo['weekType']!;
        continue;
      }

      // 检测教师（含括号的可能是 "教师(职称)"）
      // 排除：含周/节信息、括号内是教室/楼号（如 "(羽毛球E2504)"）
      if (teacher.isEmpty &&
          RegExp(r'[\(（]').hasMatch(line) &&
          !line.contains('周') &&
          !line.contains('节')) {
        // 检查括号内容是否是教室信息（含楼/号/室/栋/层/数字字母组合）
        final parenContent = _extractParenContent(line);
        final isRoom =
            parenContent.isNotEmpty &&
            RegExp(r'[楼号楼室教室栋层A-Za-z]\d', caseSensitive: false)
                .hasMatch(parenContent);
        if (!isRoom) {
          teacher = _extractTeacher(line);
          continue;
        }
      }

      // 检测教室（含楼/号/室/教等关键词）
      if (room.isEmpty &&
          RegExp(r'[楼号楼室教室栋层A-Z]\d', caseSensitive: false).hasMatch(line)) {
        room = line;
        continue;
      }

      // 如果还没识别到教师，且不是周次/教室信息
      if (teacher.isEmpty &&
          !line.contains('周') &&
          !line.contains('节') &&
          !RegExp(r'[楼号楼室教室栋层]').hasMatch(line)) {
        teacher = _extractTeacher(line);
        continue;
      }

      // 其余情况归为教室
      if (room.isEmpty) {
        room = line;
      }
    }

    return Course(
      id: '',
      name: name,
      room: room,
      teacher: teacher,
      day: day,
      startPeriod: startPeriod,
      duration: 2,
      startWeek: wStart,
      endWeek: wEnd,
      weekType: wType,
      colorValue: _getCourseColor(name, colorMap, colorIndex),
    );
  }

  /// 尝试从一行文本中解析周次信息
  /// 支持格式: "2-6,8-17([全])[01-02节]", "3,5,7([单])[03-04节]" 等
  static Map<String, int>? _tryParseWeekLine(String line) {
    // 必须包含"周"字才认为是周次行
    if (!line.contains('周') && !line.contains('week')) return null;

    // 1. 移除所有括号内容（[01-02节], ([全]) 等），保留周次范围文本
    final cleaned =
        line.replaceAll(RegExp(r'[\[\(（【][^\]\)）】]*[\]\)）】]'), '').trim();

    // 2. 从清理后的文本中提取逗号分隔的范围: "2-6,8-17"
    final rangePattern = RegExp(r'(\d+)\s*[-~—]\s*(\d+)');
    final ranges = <int>[];
    for (final m in rangePattern.allMatches(cleaned)) {
      final start = int.parse(m.group(1)!);
      final end = int.parse(m.group(2)!);
      for (int i = start; i <= end; i++) {
        ranges.add(i);
      }
    }
    if (ranges.isEmpty) return null;

    // 3. 从原始文本判断单双周
    int weekType = 0;
    if (line.contains('单周') || line.contains('([单])') || line.contains('[单]')) {
      weekType = 1;
    } else if (line.contains('双周') || line.contains('([双])') || line.contains('[双]')) {
      weekType = 2;
    }

    ranges.sort();
    return {
      'startWeek': ranges.first,
      'endWeek': ranges.last,
      'weekType': weekType,
    };
  }

  /// 从单行文本中尝试提取课程信息
  static Map<String, String> _extractFromSingleLine(String text) {
    String name = text;
    String teacher = '';
    String room = '';

    // 尝试用分隔符拆分
    final separators = RegExp(r'[|│/／\s]{2,}');
    if (separators.hasMatch(text)) {
      final parts = text.split(separators).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) name = parts[0];
      if (parts.length > 1) teacher = parts[1];
      if (parts.length > 2) room = parts[2];
    }

    return {'name': name, 'teacher': teacher, 'room': room};
  }

  /// 从 "教师(职称)" 中提取教师名
  static String _extractTeacher(String text) {
    final match = RegExp(r'^(.+?)[\(（]').firstMatch(text);
    return match?.group(1)?.trim() ?? text.trim();
  }

  /// 提取括号内的内容
  static String _extractParenContent(String text) {
    final match = RegExp(r'[\(（]([^)）]+)[\)）]').firstMatch(text);
    return match?.group(1)?.trim() ?? '';
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
    try {
      return cell.value?.toString() ?? '';
    } catch (_) {
      return cell.toString();
    }
  }
}

class _WeekdayPos {
  final int row;
  final int col;
  final int weekday;
  _WeekdayPos(this.row, this.col, this.weekday);
}
