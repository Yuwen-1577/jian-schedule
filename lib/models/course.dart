import 'dart:convert';

class Course {
  final String id;
  String name;
  String room;
  String teacher;
  int day; // 1=周一 ... 7=周日
  int startPeriod; // 开始节次(从1开始)
  int duration; // 持续节数
  int startWeek; // 起始周
  int endWeek; // 结束周
  int weekType; // 0=全周, 1=单周, 2=双周
  int colorValue; // 课程颜色 ARGB
  String note;
  String scheduleSetId; // 所属课表集 ID

  Course({
    required this.id,
    required this.name,
    this.room = '',
    this.teacher = '',
    required this.day,
    required this.startPeriod,
    this.duration = 2,
    this.startWeek = 1,
    this.endWeek = 20,
    this.weekType = 0,
    this.colorValue = 0xFF4CAF50,
    this.note = '',
    this.scheduleSetId = '',
  });

  // 判断该课程在指定周次是否上课
  bool isActiveInWeek(int week) {
    if (week < startWeek || week > endWeek) return false;
    if (weekType == 1 && week % 2 == 0) return false; // 单周，排除双周
    if (weekType == 2 && week % 2 == 1) return false; // 双周，排除单周
    return true;
  }

  // 结束节次
  int get endPeriod => startPeriod + duration - 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'room': room,
      'teacher': teacher,
      'day': day,
      'startPeriod': startPeriod,
      'duration': duration,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'weekType': weekType,
      'colorValue': colorValue,
      'note': note,
      'scheduleSetId': scheduleSetId,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String,
      name: map['name'] as String,
      room: map['room'] as String? ?? '',
      teacher: map['teacher'] as String? ?? '',
      day: map['day'] as int,
      startPeriod: map['startPeriod'] as int,
      duration: map['duration'] as int? ?? 2,
      startWeek: map['startWeek'] as int? ?? 1,
      endWeek: map['endWeek'] as int? ?? 20,
      weekType: map['weekType'] as int? ?? 0,
      colorValue: map['colorValue'] as int? ?? 0xFF4CAF50,
      note: map['note'] as String? ?? '',
      scheduleSetId: map['scheduleSetId'] as String? ?? '',
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
    int? startWeek,
    int? endWeek,
    int? weekType,
    int? colorValue,
    String? note,
    String? scheduleSetId,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      room: room ?? this.room,
      teacher: teacher ?? this.teacher,
      day: day ?? this.day,
      startPeriod: startPeriod ?? this.startPeriod,
      duration: duration ?? this.duration,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      weekType: weekType ?? this.weekType,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      scheduleSetId: scheduleSetId ?? this.scheduleSetId,
    );
  }
}
