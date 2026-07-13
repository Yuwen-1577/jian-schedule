import 'package:flutter/foundation.dart';

class TimeUtils {
  static int parseMinutes(String time) {
    try {
      final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
      if (match == null) throw const FormatException('时间格式无效');
      return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    } catch (e) {
      debugPrint('Failed to parse time "$time": $e');
      return 0;
    }
  }
}
