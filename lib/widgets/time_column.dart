import 'package:flutter/material.dart';
import '../models/time_slot.dart';
import '../theme/app_theme.dart';

class TimeColumn extends StatelessWidget {
  final List<TimeSlot> timeSlots;
  final double periodHeight;
  final double width;

  const TimeColumn({
    super.key,
    required this.timeSlots,
    required this.periodHeight,
    this.width = ScheduleDim.timeColumnWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(right: BorderSide(color: cs.outlineVariant, width: 0.5)),
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
                  slot.startTime,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                Text(
                  slot.endTime,
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    height: 1.2,
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
