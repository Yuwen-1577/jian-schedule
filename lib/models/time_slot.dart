import 'dart:convert';

class TimeSlot {
  int period; // 节次编号 (1开始)
  String startTime; // 开始时间 "08:00"
  String endTime; // 结束时间 "08:45"

  TimeSlot({
    required this.period,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      period: map['period'] as int,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory TimeSlot.fromJson(String source) =>
      TimeSlot.fromMap(json.decode(source) as Map<String, dynamic>);
}

// 默认上课时间表
List<TimeSlot> defaultTimeSlots = [
  TimeSlot(period: 1, startTime: '08:00', endTime: '08:45'),
  TimeSlot(period: 2, startTime: '08:55', endTime: '09:40'),
  TimeSlot(period: 3, startTime: '10:00', endTime: '10:45'),
  TimeSlot(period: 4, startTime: '10:55', endTime: '11:40'),
  TimeSlot(period: 5, startTime: '14:00', endTime: '14:45'),
  TimeSlot(period: 6, startTime: '14:55', endTime: '15:40'),
  TimeSlot(period: 7, startTime: '16:00', endTime: '16:45'),
  TimeSlot(period: 8, startTime: '16:55', endTime: '17:40'),
  TimeSlot(period: 9, startTime: '19:00', endTime: '19:45'),
  TimeSlot(period: 10, startTime: '19:55', endTime: '20:40'),
  TimeSlot(period: 11, startTime: '20:50', endTime: '21:35'),
  TimeSlot(period: 12, startTime: '21:45', endTime: '22:30'),
];
