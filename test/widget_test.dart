import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';
import 'package:simple_schedule/models/time_slot.dart';
import 'package:simple_schedule/models/schedule_set.dart';

void main() {
  group('Course model', () {
    test('isActiveInWeek returns true for active week', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 1,
        startWeek: 1,
        endWeek: 20,
        weekType: 0,
      );
      expect(course.isActiveInWeek(1), true);
      expect(course.isActiveInWeek(10), true);
      expect(course.isActiveInWeek(20), true);
    });

    test('isActiveInWeek returns false for out of range', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 1,
        startWeek: 3,
        endWeek: 10,
      );
      expect(course.isActiveInWeek(1), false);
      expect(course.isActiveInWeek(2), false);
      expect(course.isActiveInWeek(11), false);
    });

    test('odd week type filters correctly', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 1,
        startWeek: 1,
        endWeek: 10,
        weekType: 1, // odd weeks only
      );
      expect(course.isActiveInWeek(1), true);  // odd
      expect(course.isActiveInWeek(2), false);  // even
      expect(course.isActiveInWeek(3), true);   // odd
      expect(course.isActiveInWeek(4), false);  // even
    });

    test('even week type filters correctly', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 1,
        startWeek: 1,
        endWeek: 10,
        weekType: 2, // even weeks only
      );
      expect(course.isActiveInWeek(1), false); // odd
      expect(course.isActiveInWeek(2), true);  // even
      expect(course.isActiveInWeek(3), false); // odd
      expect(course.isActiveInWeek(4), true);  // even
    });

    test('endPeriod calculates correctly', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 3,
        duration: 2,
      );
      expect(course.endPeriod, 4);
    });

    test('toMap and fromMap round-trip', () {
      final course = Course(
        id: 'test-id',
        name: 'Physics',
        room: 'A101',
        teacher: 'Dr. Smith',
        day: 3,
        startPeriod: 5,
        duration: 3,
        startWeek: 1,
        endWeek: 16,
        weekType: 1,
        colorValue: 0xFFE57373,
        note: 'Lab coat required',
        scheduleSetId: 'set-1',
        reminderMinutesBefore: 30,
      );
      final map = course.toMap();
      final restored = Course.fromMap(map);
      expect(restored.id, course.id);
      expect(restored.name, course.name);
      expect(restored.room, course.room);
      expect(restored.teacher, course.teacher);
      expect(restored.day, course.day);
      expect(restored.startPeriod, course.startPeriod);
      expect(restored.duration, course.duration);
      expect(restored.startWeek, course.startWeek);
      expect(restored.endWeek, course.endWeek);
      expect(restored.weekType, course.weekType);
      expect(restored.colorValue, course.colorValue);
      expect(restored.note, course.note);
      expect(restored.scheduleSetId, course.scheduleSetId);
      expect(restored.reminderMinutesBefore, course.reminderMinutesBefore);
    });

    test('fromMap handles missing optional fields gracefully', () {
      final map = <String, dynamic>{
        'id': 'id-1',
        'name': 'Math',
        'day': 1,
        'startPeriod': 1,
      };
      final course = Course.fromMap(map);
      expect(course.id, 'id-1');
      expect(course.name, 'Math');
      expect(course.room, '');
      expect(course.teacher, '');
      expect(course.duration, 2);
      expect(course.startWeek, 1);
      expect(course.endWeek, 20);
      expect(course.reminderMinutesBefore, 15); // 默认值
    });

    test('copyWith creates a new instance with overrides', () {
      final course = Course(
        id: '1',
        name: 'Math',
        day: 1,
        startPeriod: 1,
      );
      final copy = course.copyWith(name: 'Physics', day: 3);
      expect(copy.name, 'Physics');
      expect(copy.day, 3);
      expect(copy.id, '1'); // unchanged
      expect(copy.startPeriod, 1); // unchanged
    });
  });

  group('TimeSlot model', () {
    test('toMap and fromMap round-trip', () {
      final slot = TimeSlot(period: 1, startTime: '08:00', endTime: '08:45');
      final map = slot.toMap();
      final restored = TimeSlot.fromMap(map);
      expect(restored.period, 1);
      expect(restored.startTime, '08:00');
      expect(restored.endTime, '08:45');
    });
  });

  group('ScheduleSet model', () {
    test('generates UUID when id not provided', () {
      final set = ScheduleSet(
        name: 'Test Set',
        semesterStart: DateTime(2025, 2, 17),
      );
      expect(set.id, isNotEmpty);
      expect(set.id.length, 36); // UUID v4 length
    });

    test('toMap and fromMap round-trip', () {
      final set = ScheduleSet(
        id: 'test-set-id',
        name: 'Fall 2025',
        semesterStart: DateTime(2025, 9, 1),
        sortOrder: 5,
      );
      final map = set.toMap();
      final restored = ScheduleSet.fromMap(map);
      expect(restored.id, 'test-set-id');
      expect(restored.name, 'Fall 2025');
      expect(restored.semesterStart, DateTime(2025, 9, 1));
      expect(restored.sortOrder, 5);
    });
  });
}
