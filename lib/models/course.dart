import 'dart:convert';

class Course {
  final String id;
  String name;
  String room;
  String teacher;
  int day; // 1=周一 ... 7=周日
  int startPeriod; // 开始节次(从1开始)
  int duration; // 持续节数
  List<int> activeWeeks; // 实际生效的上课周数
  int colorValue; // 课程颜色 ARGB
  String note;
  String scheduleSetId; // 所属课表集 ID
  int reminderMinutesBefore; // 提前提醒分钟数，0=不提醒

  Course({
    required this.id,
    required this.name,
    this.room = '',
    this.teacher = '',
    required this.day,
    required this.startPeriod,
    this.duration = 2,
    this.activeWeeks = const [],
    this.colorValue = 0xFF4CAF50,
    this.note = '',
    this.scheduleSetId = '',
    this.reminderMinutesBefore = 15,
  });

  // 判断该课程在指定周次是否上课
  bool isActiveInWeek(int week) {
    return activeWeeks.contains(week);
  }

  // 结束节次
  int get endPeriod => startPeriod + duration - 1;

  // 格式化展示活跃周次 (例如: "第 1-16 周 双周")
  String get formattedWeeks {
    if (activeWeeks.isEmpty) return '未设置';
    final sorted = List<int>.from(activeWeeks)..sort();
    
    // 判断是否为纯单周或纯双周且连续
    bool isOddEvenSequence = sorted.length > 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] - sorted[i] != 2) {
        isOddEvenSequence = false;
        break;
      }
    }
    
    if (isOddEvenSequence) {
      if (sorted.first % 2 != 0) {
        return '第 ${sorted.first}-${sorted.last} 周 单周';
      } else {
        return '第 ${sorted.first}-${sorted.last} 周 双周';
      }
    }

    // 判断是否为完全连续的周次
    bool isContinuous = sorted.length > 1;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] - sorted[i] != 1) {
        isContinuous = false;
        break;
      }
    }
    
    if (isContinuous) {
      return '第 ${sorted.first}-${sorted.last} 周';
    }

    List<String> parts = [];
    int start = sorted.first;
    int prev = start;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == prev + 1) {
        prev = sorted[i];
      } else {
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = sorted[i];
        prev = start;
      }
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return '${parts.join(', ')}周';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'room': room,
      'teacher': teacher,
      'day': day,
      'startPeriod': startPeriod,
      'duration': duration,
      'activeWeeks': jsonEncode(activeWeeks),
      'colorValue': colorValue,
      'note': note,
      'scheduleSetId': scheduleSetId,
      'reminderMinutesBefore': reminderMinutesBefore,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      room: map['room'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      day: map['day'] as int,
      startPeriod: map['startPeriod'] as int,
      duration: map['duration'] as int? ?? 2,
      activeWeeks: _parseActiveWeeks(map),
      colorValue: map['colorValue'] as int? ?? 0xFF4CAF50,
      note: map['note'] as String? ?? '',
      scheduleSetId: map['scheduleSetId'] as String? ?? '',
      reminderMinutesBefore: map['reminderMinutesBefore'] as int? ?? 15,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Course.fromJson(String source) =>
      Course.fromMap(json.decode(source) as Map<String, dynamic>);

  Course copyWith({
    String? id,
    String? name,
    String? room,
    String? teacher,
    int? day,
    int? startPeriod,
    int? duration,
    List<int>? activeWeeks,
    int? colorValue,
    String? note,
    String? scheduleSetId,
    int? reminderMinutesBefore,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      teacher: teacher ?? this.teacher,
      day: day ?? this.day,
      startPeriod: startPeriod ?? this.startPeriod,
      duration: duration ?? this.duration,
      activeWeeks: activeWeeks ?? this.activeWeeks,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      scheduleSetId: scheduleSetId ?? this.scheduleSetId,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }

  static List<int> _parseActiveWeeks(Map<String, dynamic> map) {
    List<int> parsed = [];
    if (map['activeWeeks'] != null) {
      try {
        final decoded = jsonDecode(map['activeWeeks'] as String);
        if (decoded is List) {
          parsed = decoded.map((e) => e as int).toList();
        }
      } catch (_) {}
    }

    // 如果无数据（旧数据兼容），根据旧的 startWeek, endWeek, weekType 生成
    if (parsed.isEmpty) {
      final sw = map['startWeek'] as int? ?? 1;
      final ew = map['endWeek'] as int? ?? 20;
      final wt = map['weekType'] as int? ?? 0;
      for (int i = sw; i <= ew; i++) {
        if (wt == 1 && i % 2 == 0) continue;
        if (wt == 2 && i % 2 == 1) continue;
        parsed.add(i);
      }
    }
    return parsed;
  }
}
