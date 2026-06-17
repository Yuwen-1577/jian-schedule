import 'package:flutter/foundation.dart';

class TimeUtils {
  static int parseMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      debugPrint('Failed to parse time "$time": $e');
      return 0;
    }
  }
}
