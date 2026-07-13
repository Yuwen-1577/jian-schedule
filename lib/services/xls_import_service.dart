import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../utils/constants.dart';

/// Excel 课表导入服务
/// 支持多种格式：标准周视图、分段视图、单行单节、合并单元格等
class XlsImportService {
  /// 解析 xlsx 文件，返回课程列表
  static Future<List<Course>> parseFile(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('文件中没有找到工作表');
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    return _parseSheet(excel, sheetName, sheet);
  }

  static List<Course> _parseSheet(Excel excel, String sheetName, Sheet sheet) {
    final rows = sheet.rows;
    if (rows.length < 3) {
      throw Exception('工作表数据不足');
    }

    // 1. 构建二维字符串网格（使用合并单元格 API，失败时降级）
    List<List<String>> grid;
    try {
      grid = _buildGridWithMerge(excel, sheetName, sheet, rows);
    } catch (e) {
      debugPrint('合并单元格 API 失败，使用降级方案: $e');
      grid = _buildGridWithMergeFallback(sheet, rows);
    }

    // 2. 智能表头检测
    final headerInfo = _detectHeader(grid);
    if (headerInfo == null) {
      throw Exception('未找到课表表头（星期一~星期日）');
    }

    final headerRow = headerInfo['headerRow']!;
    final dayColMap = headerInfo['dayColMap'] as Map<int, int>;
    final timeSlotColumns = headerInfo['timeSlotColumns'] as List<int>;

    // 3. 确定数据范围
    final dataRange = _detectDataRange(grid, headerRow, dayColMap);
    final dataStartRow = dataRange['start']!;
    final dataEndRow = dataRange['end']!;

    // 4. 逐行解析课程
    final courses = <Course>[];
    final colorMap = <String, int>{};
    int colorIndex = 0;

    for (int r = dataStartRow; r < dataEndRow; r++) {
      // 跳过分段行（上午/下午/晚上）
      final firstCell = grid[r].isNotEmpty ? grid[r][0].trim() : '';
      if (_isSegmentHeader(firstCell)) {
        continue;
      }

      // 检测当前行的节次
      final startPeriod = _calculateStartPeriod(
        grid,
        r,
        dataStartRow,
        timeSlotColumns,
      );

      // 解析每一天的课程
      for (final entry in dayColMap.entries) {
        final day = entry.key;
        final col = entry.value;

        if (col >= grid[r].length) continue;
        final cellText = grid[r][col].trim();
        if (cellText.isEmpty) continue;

        final dayCourses = _parseCell(
          cellText,
          day,
          startPeriod,
          colorMap,
          colorIndex,
        );
        courses.addAll(dayCourses);
        colorIndex += dayCourses.length;
      }
    }

    // 5. 合并同名课程
    final mergedCourses = _mergeCourses(courses);

    // 6. 分配颜色
    const uuidGen = Uuid();
    final result = <Course>[];
    int finalColorIndex = 0;
    for (final course in mergedCourses) {
      result.add(
        Course(
          id: uuidGen.v4(),
          name: course.name,
          room: course.room,
          teacher: course.teacher,
          day: course.day,
          startPeriod: course.startPeriod,
          duration: course.duration,
          activeWeeks: List.from(course.activeWeeks),
          colorValue: _getCourseColor(course.name, colorMap, finalColorIndex),
        ),
      );
      finalColorIndex++;
    }

    return result;
  }

  /// 构建二维字符串网格（使用 excel 包的合并单元格 API）
  static List<List<String>> _buildGridWithMerge(
    Excel excel,
    String sheetName,
    Sheet sheet,
    List<List<dynamic>> rows,
  ) {
    // 1. 解析所有合并范围
    final mergedRanges = <_MergeRange>[];
    try {
      final mergedStrings = excel.getMergedCells(sheetName);
      for (final s in mergedStrings) {
        final range = _MergeRange.parse(s);
        if (range != null) mergedRanges.add(range);
      }
    } catch (e) {
      debugPrint('Failed to read merged cells: $e');
    }

    // 2. 构建 "被合并覆盖的单元格 → 左上角值" 映射
    final mergeMap = <String, String>{};
    for (final range in mergedRanges) {
      // 读取左上角单元格的值
      String topLeftValue = '';
      if (range.startRow < rows.length &&
          range.startCol < rows[range.startRow].length) {
        topLeftValue = _cellToString(rows[range.startRow][range.startCol]);
      }
      // 填充范围内所有单元格
      for (int r = range.startRow; r <= range.endRow; r++) {
        for (int c = range.startCol; c <= range.endCol; c++) {
          if (r == range.startRow && c == range.startCol) continue;
          mergeMap['$r:$c'] = topLeftValue;
        }
      }
    }

    // 3. 构建网格
    final grid = <List<String>>[];
    for (int r = 0; r < rows.length; r++) {
      final cells = <String>[];
      for (int c = 0; c < rows[r].length; c++) {
        final raw = _cellToString(rows[r][c]);
        if (raw.isEmpty && mergeMap.containsKey('$r:$c')) {
          cells.add(mergeMap['$r:$c']!);
        } else {
          cells.add(raw);
        }
      }
      grid.add(cells);
    }

    return grid;
  }

  /// 合并范围数据类
  static List<List<String>> _buildGridWithMergeFallback(
    Sheet sheet,
    List<List<dynamic>> rows,
  ) {
    // 降级方案：启发式检测（当 API 不可用时）
    final grid = <List<String>>[];
    for (int r = 0; r < rows.length; r++) {
      final cells = <String>[];
      for (int c = 0; c < rows[r].length; c++) {
        final raw = _cellToString(rows[r][c]);
        if (raw.isEmpty) {
          // 向左搜索同行
          for (int lc = c - 1; lc >= 0; lc--) {
            final leftVal = _cellToString(rows[r][lc]);
            if (leftVal.isNotEmpty) {
              bool allBetweenEmpty = true;
              for (int mc = lc + 1; mc < c; mc++) {
                if (_cellToString(rows[r][mc]).isNotEmpty) {
                  allBetweenEmpty = false;
                  break;
                }
              }
              if (allBetweenEmpty) {
                cells.add(leftVal);
                break;
              }
            }
          }
          if (cells.length == c) cells.add('');
        } else {
          cells.add(raw);
        }
      }
      grid.add(cells);
    }
    return grid;
  }

  /// 智能表头检测
  static Map<String, dynamic>? _detectHeader(List<List<String>> grid) {
    // 找到所有包含星期关键词的单元格位置
    final weekdayPositions = <_WeekdayPos>[];
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final weekday = detectWeekday(grid[r][c]);
        if (weekday > 0) {
          weekdayPositions.add(_WeekdayPos(r, c, weekday));
        }
      }
    }

    if (weekdayPositions.isEmpty) return null;

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
    final dayColMap = <int, int>{};
    for (final pos in rowGroups[headerRow]!) {
      dayColMap.putIfAbsent(pos.weekday, () => pos.col);
    }

    // 检测时间列（左侧列包含节次标注）
    final timeSlotColumns = <int>[];
    if (dayColMap.isNotEmpty) {
      final minCol = dayColMap.values.reduce((a, b) => a < b ? a : b);
      for (int c = 0; c < minCol; c++) {
        // 检查这一列是否有节次标注
        bool hasPeriodInfo = false;
        for (
          int r = headerRow + 1;
          r < grid.length && r < headerRow + 20;
          r++
        ) {
          if (c < grid[r].length && _detectPeriodFromRow(grid[r][c]) > 0) {
            hasPeriodInfo = true;
            break;
          }
        }
        if (hasPeriodInfo) {
          timeSlotColumns.add(c);
        }
      }
    }

    return {
      'headerRow': headerRow,
      'dayColMap': dayColMap,
      'timeSlotColumns': timeSlotColumns,
    };
  }

  /// 检测是否为分段行（上午/下午/晚上）
  static bool _isSegmentHeader(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final segments = [
      '上午',
      '下午',
      '晚上',
      '早',
      '午',
      '晚',
      'morning',
      'afternoon',
      'evening',
    ];
    return segments.any((s) => t.toLowerCase().contains(s.toLowerCase()));
  }

  /// 从行文本中检测节次信息（仅返回起始节次）
  static int _detectPeriodFromRow(String text) {
    final range = _detectPeriodRange(text);
    return range != null ? range[0] : 0;
  }

  /// 从行文本中检测起止节次，返回 [start, end]，无法检测返回 null
  static List<int>? _detectPeriodRange(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;

    // 带范围: "1-2节", "第3-4节", "01-02节"
    final rangePattern = RegExp(r'^第?\s*0*(\d{1,2})\s*[-~—]\s*0*(\d{1,2})\s*节');
    final rangeMatch = rangePattern.firstMatch(t);
    if (rangeMatch != null) {
      final start = int.parse(rangeMatch.group(1)!);
      final end = int.parse(rangeMatch.group(2)!);
      return [start, end];
    }

    // 单节: "3节", "第5节"
    final singlePattern = RegExp(r'^第?\s*0*(\d{1,2})\s*节');
    final singleMatch = singlePattern.firstMatch(t);
    if (singleMatch != null) {
      final p = int.parse(singleMatch.group(1)!);
      return [p, p];
    }

    return null;
  }

  /// 智能计算节次
  static int _calculateStartPeriod(
    List<List<String>> grid,
    int row,
    int dataStartRow,
    List<int> timeSlotColumns,
  ) {
    // 方法1: 从时间列检测节次
    for (final col in timeSlotColumns) {
      if (col < grid[row].length) {
        final periodText = grid[row][col];
        final detectedPeriod = _detectPeriodFromRow(periodText);
        if (detectedPeriod > 0) {
          return detectedPeriod;
        }
      }
    }

    // 方法2: 检查整行是否有节次信息
    for (int c = 0; c < grid[row].length; c++) {
      final detectedPeriod = _detectPeriodFromRow(grid[row][c]);
      if (detectedPeriod > 0) {
        return detectedPeriod;
      }
    }

    // 方法3: 回退 — 每行默认对应 2 节课（1-2, 3-4, ...），这是最常见的课表布局
    final slotIndex = row - dataStartRow;
    return slotIndex * 2 + 1;
  }

  /// 确定数据范围
  static Map<String, int> _detectDataRange(
    List<List<String>> grid,
    int headerRow,
    Map<int, int> dayColMap,
  ) {
    int dataStartRow = headerRow + 1;
    int dataEndRow = grid.length;

    for (int r = dataStartRow; r < grid.length; r++) {
      // 检查是否是新的表头行（包含多个星期关键词）
      int weekdayCount = 0;
      for (int c = 0; c < grid[r].length; c++) {
        if (detectWeekday(grid[r][c]) > 0) weekdayCount++;
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

      if (allEmpty && r + 1 < grid.length) {
        bool nextAllEmpty = true;
        for (final col in dayColMap.values) {
          if (col < grid[r + 1].length && grid[r + 1][col].trim().isNotEmpty) {
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

    return {'start': dataStartRow, 'end': dataEndRow};
  }

  /// 检测文本中是否包含星期关键词
  @visibleForTesting
  static int detectWeekday(String text) {
    final t = text.trim();

    const fullMatchMap = {
      '星期一': 1,
      '周一': 1,
      '一': 1,
      'Mon': 1,
      'Monday': 1,
      '星期二': 2,
      '周二': 2,
      '二': 2,
      'Tue': 2,
      'Tuesday': 2,
      '星期三': 3,
      '周三': 3,
      '三': 3,
      'Wed': 3,
      'Wednesday': 3,
      '星期四': 4,
      '周四': 4,
      '四': 4,
      'Thu': 4,
      'Thursday': 4,
      '星期五': 5,
      '周五': 5,
      '五': 5,
      'Fri': 5,
      'Friday': 5,
      '星期六': 6,
      '周六': 6,
      '六': 6,
      'Sat': 6,
      'Saturday': 6,
      '星期日': 7,
      '星期天': 7,
      '周日': 7,
      '周天': 7,
      '日': 7,
      '天': 7,
      'Sun': 7,
      'Sunday': 7,
    };

    if (fullMatchMap.containsKey(t)) return fullMatchMap[t]!;

    const containsMap = {
      '星期一': 1,
      '周一': 1,
      '星期二': 2,
      '周二': 2,
      '星期三': 3,
      '周三': 3,
      '星期四': 4,
      '周四': 4,
      '星期五': 5,
      '周五': 5,
      '星期六': 6,
      '周六': 6,
      '星期日': 7,
      '星期天': 7,
      '周日': 7,
    };
    for (final entry in containsMap.entries) {
      if (t.contains(entry.key)) return entry.value;
    }

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
    List<String> blocks = [];

    // 策略1: 双换行分割（最可靠 — 课程之间通常有空行）
    blocks = text.split(RegExp(r'\n\s*\n'));

    // 策略2: 如果只有一块，尝试用管道符分割（多课程挤在同一单元格）
    if (blocks.length == 1 && blocks[0].contains(RegExp(r'[|│/／]'))) {
      blocks = text.split(RegExp(r'[|│/／]'));
    }

    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;

      final course = _parseSingleCourse(
        trimmed,
        day,
        startPeriod,
        colorMap,
        colorIndex,
      );
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
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    String name = '';
    String teacher = '';
    String room = '';
    List<int> activeWeeks = List.generate(maxWeekCount, (i) => i + 1);
    int duration = 2; // 默认值，会被实际检测覆盖

    // 扫描所有行找节次范围
    for (final line in lines) {
      final range = _detectPeriodRange(line);
      if (range != null) {
        duration = range[1] - range[0] + 1;
        break;
      }
    }

    // 第一行通常是课程名
    name = lines[0];

    // 如果只有一行，尝试从里面提取信息
    if (lines.length == 1) {
      final info = _extractFromSingleLine(lines[0]);
      if (info['name']!.isNotEmpty) name = info['name']!;
      if (info['teacher']!.isNotEmpty) teacher = info['teacher']!;
      if (info['room']!.isNotEmpty) room = info['room']!;
      activeWeeks = tryParseWeekLine(lines[0]) ?? activeWeeks;
      return Course(
        id: '',
        name: name,
        room: room,
        teacher: teacher,
        day: day,
        startPeriod: startPeriod,
        duration: duration,
        activeWeeks: activeWeeks,
        colorValue: _getCourseColor(name, colorMap, colorIndex),
      );
    }

    // 多行：逐行分析
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];

      // 跳过节次信息行（如 "第1-2节"、"01-02节"）
      if (_detectPeriodFromRow(line) > 0) continue;

      // 检测周次信息
      final weekInfo = tryParseWeekLine(line);
      if (weekInfo != null) {
        activeWeeks = weekInfo;
        continue;
      }

      // 检测教师（含括号的可能是 "教师(职称)"）
      if (teacher.isEmpty &&
          RegExp(r'[\(（]').hasMatch(line) &&
          !line.contains('周') &&
          !line.contains('节')) {
        final parenContent = _extractParenContent(line);
        final isRoom =
            parenContent.isNotEmpty &&
            RegExp(
              r'[楼号楼室教室栋层A-Za-z]\d',
              caseSensitive: false,
            ).hasMatch(parenContent);
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
      duration: duration,
      activeWeeks: activeWeeks,
      colorValue: _getCourseColor(name, colorMap, colorIndex),
    );
  }

  /// 合并同名课程
  static List<Course> _mergeCourses(List<Course> courses) {
    final mergeMap = <String, _MergeGroup>{};

    for (final course in courses) {
      // 合并键: name + teacher + day + startPeriod
      final key =
          '${course.name}_${course.teacher}_${course.day}_${course.startPeriod}';

      if (mergeMap.containsKey(key)) {
        // 合并周次
        final group = mergeMap[key]!;
        group.weeks.addAll(course.activeWeeks);
        final uniqueWeeks = group.weeks.toSet().toList()..sort();
        group.weeks.clear();
        group.weeks.addAll(uniqueWeeks);

        // 保留所有唯一的教室（如果当前为空但新值不为空，则更新）
        if (group.room.isEmpty && course.room.isNotEmpty) {
          group.room = course.room;
        }
      } else {
        // 创建新的合并组
        mergeMap[key] = _MergeGroup(
          name: course.name,
          teacher: course.teacher,
          room: course.room,
          day: course.day,
          startPeriod: course.startPeriod,
          duration: course.duration,
          weeks: List.from(course.activeWeeks),
        );
      }
    }

    // 转换为 Course 列表
    final merged = <Course>[];
    for (final group in mergeMap.values) {
      merged.add(
        Course(
          id: '',
          name: group.name,
          room: group.room,
          teacher: group.teacher,
          day: group.day,
          startPeriod: group.startPeriod,
          duration: group.duration,
          activeWeeks: group.weeks,
          colorValue: 0,
        ),
      );
    }

    return merged;
  }

  /// 尝试从一行文本中解析周次信息
  /// 支持格式: "2-6,8-17([全])[01-02节]", "3,5,7([单])[03-04节]", "11(周)" 等
  @visibleForTesting
  static List<int>? tryParseWeekLine(String line) {
    if (!line.contains('周') && !line.toLowerCase().contains('week')) {
      return null;
    }

    // 1. 清理括号内容 + 残留节次信息（如 [01-02节] 未被括号匹配的 "01-02节"）
    var cleaned = line
        .replaceAll(RegExp(r'[\[\(（【][^\]\)）】]*[\]\)）】]'), '')
        .trim();
    // 移除 "数字-数字节" 和 "数字节" 模式（防止节次范围污染周次解析）
    cleaned = cleaned.replaceAll(RegExp(r'\d+\s*[-~—]\s*\d+\s*节'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d+\s*节'), '');
    cleaned = cleaned.trim();

    // 2. 提取所有周次范围和单独周
    final weeks = <int>{};

    // 格式: "2-6", "8-17", "1-16"
    final rangePattern = RegExp(r'(\d+)\s*[-~—]\s*(\d+)');
    for (final m in rangePattern.allMatches(cleaned)) {
      final start = int.parse(m.group(1)!);
      final end = int.parse(m.group(2)!);
      for (int i = start; i <= end; i++) {
        if (i >= 1 && i <= maxWeekCount) weeks.add(i);
      }
    }

    // 格式: "11", "1,3,5,7" (单个数字，用逗号或空格分隔)
    final singlePattern = RegExp(r'(\d+)');
    for (final m in singlePattern.allMatches(cleaned)) {
      final week = int.parse(m.group(1)!);
      if (week >= 1 && week <= maxWeekCount) weeks.add(week);
    }

    if (weeks.isEmpty) return null;

    // 3. 判断单双周
    final isOdd =
        line.contains('单周') || line.contains('([单])') || line.contains('[单]');
    final isEven =
        line.contains('双周') || line.contains('([双])') || line.contains('[双]');

    final result = weeks.where((week) {
      if (isOdd) return week.isOdd;
      if (isEven) return week.isEven;
      return true;
    }).toList()..sort();
    return result.isEmpty ? null : result;
  }

  /// 从单行文本中尝试提取课程信息
  static Map<String, String> _extractFromSingleLine(String text) {
    String name = text;
    String teacher = '';
    String room = '';

    // 尝试用分隔符拆分
    final separators = RegExp(r'[|│/／\s]{2,}');
    if (separators.hasMatch(text)) {
      final parts = text
          .split(separators)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
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
    String name,
    Map<String, int> colorMap,
    int fallbackIndex,
  ) {
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
    } catch (e) {
      debugPrint('Failed to read cell value: $e');
      return cell.toString();
    }
  }
}

class _WeekdayPos {
  final int row;
  final int col;
  final int weekday;
  const _WeekdayPos(this.row, this.col, this.weekday);
}

class _MergeRange {
  final int startRow, startCol, endRow, endCol;
  const _MergeRange(this.startRow, this.startCol, this.endRow, this.endCol);

  /// 解析 "A1:B3" 格式的合并范围
  static _MergeRange? parse(String range) {
    final parts = range.split(':');
    if (parts.length != 2) return null;
    final start = _parseCellRef(parts[0].trim());
    final end = _parseCellRef(parts[1].trim());
    if (start == null || end == null) return null;
    return _MergeRange(start[0], start[1], end[0], end[1]);
  }

  /// 解析 "A1" → [row, col]（0-based）
  static List<int>? _parseCellRef(String ref) {
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref.toUpperCase());
    if (match == null) return null;
    final colStr = match.group(1)!;
    final rowStr = match.group(2)!;
    int col = 0;
    for (int i = 0; i < colStr.length; i++) {
      col = col * 26 + (colStr.codeUnitAt(i) - 64);
    }
    return [int.parse(rowStr) - 1, col - 1];
  }
}

class _MergeGroup {
  final String name;
  String teacher;
  String room;
  final int day;
  final int startPeriod;
  final int duration;
  final List<int> weeks;

  _MergeGroup({
    required this.name,
    required this.teacher,
    required this.room,
    required this.day,
    required this.startPeriod,
    required this.duration,
    required this.weeks,
  });
}
