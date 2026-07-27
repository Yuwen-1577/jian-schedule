import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/utils/constants.dart';

void main() {
  group('calculateTeachingWeek', () {
    final semesterStart = DateTime(2026, 2, 23, 15, 30);

    test('uses seven-day boundaries without Monday off-by-one', () {
      expect(calculateTeachingWeek(semesterStart, DateTime(2026, 2, 23)), 1);
      expect(calculateTeachingWeek(semesterStart, DateTime(2026, 3, 1)), 1);
      expect(calculateTeachingWeek(semesterStart, DateTime(2026, 3, 2)), 2);
      expect(calculateTeachingWeek(semesterStart, DateTime(2026, 3, 9)), 3);
    });

    test('clamps dates before the semester and after week 25', () {
      expect(calculateTeachingWeek(semesterStart, DateTime(2026, 1, 1)), 1);
      expect(calculateTeachingWeek(semesterStart, DateTime(2027, 1, 1)), 25);
    });

    test('strict calculation returns null outside the semester', () {
      expect(
        calculateTeachingWeekOrNull(semesterStart, DateTime(2026, 1, 1)),
        isNull,
      );
      expect(
        calculateTeachingWeekOrNull(semesterStart, DateTime(2026, 2, 23)),
        1,
      );
      expect(
        calculateTeachingWeekOrNull(semesterStart, DateTime(2026, 8, 16)),
        25,
      );
      expect(
        calculateTeachingWeekOrNull(semesterStart, DateTime(2026, 8, 17)),
        isNull,
      );
    });
  });
}
