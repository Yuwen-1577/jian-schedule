import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/utils/course_parser_utils.dart';

void main() {
  group('CourseParserUtils Tests', () {
    test('parseWeeks ignores period suffix and keeps even-week marker', () {
      expect(CourseParserUtils.parseWeeks('2-16(双)[03-04节]'), [
        2,
        4,
        6,
        8,
        10,
        12,
        14,
        16,
      ]);
    });

    test('parseWeeks handles mixed single-week ranges', () {
      expect(CourseParserUtils.parseWeeks('1,3,5-10周单周'), [1, 3, 5, 7, 9]);
    });
  });
}
