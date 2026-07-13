import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/services/xls_import_service.dart';

void main() {
  group('XlsImportService.tryParseWeekLine', () {
    test('preserves gaps in discrete week ranges', () {
      expect(XlsImportService.tryParseWeekLine('2-6,8-17周'), [
        2,
        3,
        4,
        5,
        6,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
      ]);
    });

    test('keeps explicit single weeks and odd-week filtering', () {
      expect(XlsImportService.tryParseWeekLine('1,3,5,9周'), [1, 3, 5, 9]);
      expect(XlsImportService.tryParseWeekLine('1-10周单周'), [1, 3, 5, 7, 9]);
    });

    test('ignores period suffixes and clamps to supported weeks', () {
      expect(XlsImportService.tryParseWeekLine('24-30周[01-02节]'), [24, 25]);
    });
  });
}
