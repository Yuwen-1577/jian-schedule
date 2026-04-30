import 'package:flutter/material.dart';
import '../models/time_slot.dart';

class TimeColumn extends StatelessWidget {
  final List<TimeSlot> timeSlots;
  final double periodHeight;
  final double width;

  const TimeColumn({
    super.key,
    required this.timeSlots,
    required this.periodHeight,
    this.width = 48,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[400] : Colors.grey[700];
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[100];

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: timeSlots.map((slot) {
          return Container(
            height: periodHeight,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.startTime.substring(0, 5),
                  style: TextStyle(
                    fontSize: 9,
                    color: textColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  slot.endTime.substring(0, 5),
                  style: TextStyle(
                    fontSize: 8,
                    color: textColor?.withAlpha(150),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
