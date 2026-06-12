import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';
import 'package:simple_schedule/models/time_slot.dart';
import 'package:simple_schedule/models/schedule_set.dart';
import 'package:simple_schedule/utils/constants.dart';
import 'package:simple_schedule/widgets/week_grid.dart';
import 'package:simple_schedule/services/xls_import_service.dart';

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

  group('calculateCurrentWeek', () {
    test('returns 1 before semester starts', () {
      final future = DateTime.now().add(const Duration(days: 14));
      expect(calculateCurrentWeek(future), 1);
    });

    test('returns 1 on semester start day', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      expect(calculateCurrentWeek(start), 1);
    });

    test('returns 1 for first week', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 3));
      expect(calculateCurrentWeek(start), 1);
    });

    test('returns correct week in middle of semester', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 15));
      expect(calculateCurrentWeek(start), 3);
    });

    test('returns 25 at max week boundary', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 24 * 7 + 3));
      expect(calculateCurrentWeek(start), 25);
    });

    test('clamps to 25 when beyond max weeks', () {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day)
          .subtract(const Duration(days: 200));
      expect(calculateCurrentWeek(start), 25);
    });
  });

  group('isDarkColor', () {
    test('black is dark', () {
      expect(isDarkColor(0xFF000000), true);
    });

    test('white is not dark', () {
      expect(isDarkColor(0xFFFFFFFF), false);
    });

    test('mid gray is dark', () {
      expect(isDarkColor(0xFF808080), true);
    });

    test('preset colors include both dark and light', () {
      final results = presetColors.map(isDarkColor).toList();
      expect(results.contains(true), true);
      expect(results.contains(false), true);
      expect(isDarkColor(presetColors[2]), false); // yellow
      expect(isDarkColor(presetColors[9]), true); // gray
    });
  });

  group('stableId', () {
    test('is deterministic for same input', () {
      const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      expect(stableId(uuid), stableId(uuid));
    });

    test('produces unique ids for different inputs', () {
      final ids = {
        stableId('course-1'),
        stableId('course-2'),
        stableId('course-3'),
        stableId('a'),
        stableId('b'),
      };
      expect(ids.length, 5);
    });

    test('always returns positive value', () {
      const samples = ['', 'x', 'test-uuid-123', '中文课程'];
      for (final s in samples) {
        expect(stableId(s), greaterThan(0));
      }
    });
  });

  group('overlaps and calculatePlacements', () {
    Course makeCourse(String id, int start, int duration) => Course(
          id: id,
          name: id,
          day: 1,
          startPeriod: start,
          duration: duration,
        );

    test('overlaps returns false for non-overlapping courses', () {
      final a = makeCourse('a', 1, 2);
      final b = makeCourse('b', 3, 2);
      expect(overlaps(a, b), false);
    });

    test('overlaps returns true for overlapping courses', () {
      final a = makeCourse('a', 1, 3);
      final b = makeCourse('b', 2, 2);
      expect(overlaps(a, b), true);
    });

    test('calculatePlacements returns empty for empty list', () {
      expect(calculatePlacements([]), isEmpty);
    });

    test('calculatePlacements assigns single column for non-overlapping', () {
      final courses = [
        makeCourse('a', 1, 2),
        makeCourse('b', 3, 2),
      ];
      final placements = calculatePlacements(courses);
      expect(placements.length, 2);
      expect(placements.every((p) => p.totalCols == 1), true);
    });

    test('calculatePlacements splits overlapping courses into columns', () {
      final courses = [
        makeCourse('a', 1, 3),
        makeCourse('b', 2, 2),
      ];
      final placements = calculatePlacements(courses);
      expect(placements.length, 2);
      expect(placements.every((p) => p.totalCols == 2), true);
      expect(placements.map((p) => p.colOffset).toSet(), {0, 1});
    });

    test('calculatePlacements handles three mixed courses', () {
      final courses = [
        makeCourse('a', 1, 2),
        makeCourse('b', 2, 2),
        makeCourse('c', 5, 2),
      ];
      final placements = calculatePlacements(courses);
      expect(placements.length, 3);
      final cPlacement = placements.firstWhere((p) => p.course.id == 'c');
      expect(cPlacement.totalCols, 2);
      expect(cPlacement.colOffset, 0);
    });
  });

  group('detectWeekday', () {
    test('exact match for Chinese weekday', () {
      expect(XlsImportService.detectWeekday('周一'), 1);
      expect(XlsImportService.detectWeekday('星期五'), 5);
    });

    test('contains match for compound text', () {
      expect(XlsImportService.detectWeekday('课程(周三)'), 3);
    });

    test('english weekday names', () {
      expect(XlsImportService.detectWeekday('Monday'), 1);
      expect(XlsImportService.detectWeekday('Fri'), 5);
    });

    test('returns 0 for no match', () {
      expect(XlsImportService.detectWeekday(''), 0);
      expect(XlsImportService.detectWeekday('教室A101'), 0);
    });
  });

  group('tryParseWeekLine', () {
    test('parses full-week range', () {
      final result = XlsImportService.tryParseWeekLine('2-6周([全])');
      expect(result, isNotNull);
      expect(result!['startWeek'], 2);
      expect(result['endWeek'], 6);
      expect(result['weekType'], 0);
    });

    test('parses odd-week type', () {
      final result = XlsImportService.tryParseWeekLine('3,5,7([单])周');
      expect(result, isNotNull);
      expect(result!['weekType'], 1);
    });

    test('parses even-week type', () {
      final result = XlsImportService.tryParseWeekLine('2-10([双])周');
      expect(result, isNotNull);
      expect(result!['weekType'], 2);
    });

    test('returns null when no week keyword', () {
      expect(XlsImportService.tryParseWeekLine('1-3节'), isNull);
    });

    test('returns null for empty input', () {
      expect(XlsImportService.tryParseWeekLine(''), isNull);
    });
  });
}
