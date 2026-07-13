import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/utils/time_utils.dart';

void main() {
  group('TimeUtils Tests', () {
    test('parseMinutes parses correctly', () {
      expect(TimeUtils.parseMinutes('08:00'), 480);
      expect(TimeUtils.parseMinutes('12:30'), 750);
      expect(TimeUtils.parseMinutes('00:00'), 0);
      expect(TimeUtils.parseMinutes('23:59'), 1439);
    });

    test('parseMinutes handles invalid format gracefully', () {
      expect(TimeUtils.parseMinutes('800'), 0);
      expect(TimeUtils.parseMinutes('abc:def'), 0);
      expect(TimeUtils.parseMinutes(''), 0);
      expect(TimeUtils.parseMinutes('24:00'), 0);
      expect(TimeUtils.parseMinutes('08:60'), 0);
      expect(TimeUtils.parseMinutes('8:00:30'), 0);
    });
  });
}
