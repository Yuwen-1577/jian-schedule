import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/models/course.dart';

void main() {
  group('Course Model Tests', () {
    test('Course serialization and deserialization', () {
      final course = Course(
        id: '123',
        name: '测试课程',
        room: 'A101',
        teacher: '张三',
        day: 1,
        startPeriod: 1,
        duration: 2,
        activeWeeks: [1, 2, 3, 5],
        colorValue: 0xFF0000,
        scheduleSetId: 'set1',
        reminderMinutesBefore: 30,
      );

      final map = course.toMap();
      final newCourse = Course.fromMap(map);

      expect(newCourse.id, '123');
      expect(newCourse.name, '测试课程');
      expect(newCourse.room, 'A101');
      expect(newCourse.teacher, '张三');
      expect(newCourse.day, 1);
      expect(newCourse.startPeriod, 1);
      expect(newCourse.duration, 2);
      expect(newCourse.activeWeeks, [1, 2, 3, 5]);
      expect(newCourse.colorValue, 0xFF0000);
      expect(newCourse.scheduleSetId, 'set1');
      expect(newCourse.reminderMinutesBefore, 30);
    });

    test(
      'Course fromMap with legacy fields (startWeek, endWeek, weekType)',
      () {
        // 模拟旧版本 v2.3 以前的数据
        final map = {
          'id': '123',
          'name': '测试课程',
          'day': 1,
          'startPeriod': 1,
          'duration': 2,
          'startWeek': 1,
          'endWeek': 5,
          'weekType': 0, // 全周
          'colorValue': 0xFF0000,
          'scheduleSetId': 'set1',
        };

        final course = Course.fromMap(map);
        expect(course.activeWeeks, [1, 2, 3, 4, 5]);

        // 单周测试
        map['weekType'] = 1;
        final courseOdd = Course.fromMap(map);
        expect(courseOdd.activeWeeks, [1, 3, 5]);

        // 双周测试
        map['weekType'] = 2;
        final courseEven = Course.fromMap(map);
        expect(courseEven.activeWeeks, [2, 4]);
      },
    );
  });
}
