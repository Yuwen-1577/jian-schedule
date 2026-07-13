class CourseParserUtils {
  /// 将形如 "1-8周", "1,3,5-10周单周", "1,2,4周" 的字符串解析为 `List<int>`
  static List<int> parseWeeks(String weeksStr) {
    if (weeksStr.isEmpty) return [];

    final isOdd = weeksStr.contains('单');
    final isEven = weeksStr.contains('双');

    // 去除节次标记和"周"、括号等冗余字符，保留真正的周次范围。
    weeksStr = weeksStr
        .replaceAll(RegExp(r'[\[【][^\]】]*节[^\]】]*[\]】]'), '')
        .replaceAll(RegExp(r'\d+\s*[-~—－]\s*\d+\s*节'), '')
        .replaceAll(RegExp(r'\d+\s*节'), '')
        .replaceAll('第', '')
        .replaceAll('周', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('【', '')
        .replaceAll('】', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('单', '')
        .replaceAll('双', '')
        .replaceAll('全', '')
        .replaceAll(RegExp(r'\s+'), '');

    final Set<int> weeks = {};
    final parts = weeksStr.split(RegExp(r'[,，;；]'));

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.contains(RegExp(r'[-~—－]'))) {
        final range = part.split(RegExp(r'[-~—－]'));
        if (range.length == 2) {
          final start = int.tryParse(range[0]);
          final end = int.tryParse(range[1]);
          if (start == null || end == null) continue;
          for (int i = start; i <= end; i++) {
            if (isOdd && i % 2 == 0) continue;
            if (isEven && i % 2 == 1) continue;
            weeks.add(i);
          }
        }
      } else {
        final w = int.tryParse(part);
        if (w != null) {
          if (isOdd && w % 2 == 0) continue;
          if (isEven && w % 2 == 1) continue;
          weeks.add(w);
        }
      }
    }
    final result = weeks.toList()..sort();
    return result;
  }
}
