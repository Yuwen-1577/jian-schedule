import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';
import 'package:simple_schedule/models/time_slot.dart';
import 'package:simple_schedule/services/widget_service.dart';
import 'package:simple_schedule/utils/constants.dart';

void main() {
  group('WidgetService Tests', () {
    test('serializeCoursesForWidget includes activeWeeks and real times', () {
      final course = Course(
        id: 'course-24',
        name: '只在第24周上的课',
        room: 'A101',
        teacher: '张三',
        day: 2,
        startPeriod: 2,
        duration: 2,
        activeWeeks: [24],
        colorValue: 0xFF123456,
      );
      final timeSlots = [
        TimeSlot(period: 1, startTime: '08:00', endTime: '08:45'),
        TimeSlot(period: 2, startTime: '08:55', endTime: '09:40'),
        TimeSlot(period: 3, startTime: '10:00', endTime: '10:45'),
      ];

      final payload = WidgetService.serializeCoursesForWidget([
        course,
      ], timeSlots);

      expect(payload, hasLength(1));
      expect(payload.single['id'], stableId('course-24'));
      expect(payload.single['name'], '只在第24周上的课');
      expect(payload.single['activeWeeks'], [24]);
      expect(payload.single['startTime'], '08:55');
      expect(payload.single['endTime'], '10:45');
    });
  });
}
