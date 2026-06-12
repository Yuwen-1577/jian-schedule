import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';
import '../pages/course_edit_page.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class TodayCourses extends StatelessWidget {
  const TodayCourses({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday;
    final courses = provider.getCoursesForDay(provider.currentWeek, today);
    final timeSlots = provider.timeSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
          child: Row(
            children: [
              Icon(Icons.today, size: 20, color: cs.primary),
              const SizedBox(width: Gap.sm),
              Text(
                '今日课程',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                '第${provider.currentWeek}周 ${weekdayNames[today - 1]}',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Center(
              child: Text(
                '今天没有课程',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else
          ...courses.map((course) => _TodayCourseItem(
                course: course,
                timeSlots: timeSlots,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CourseEditPage(),
                    settings: RouteSettings(arguments: course),
                  ),
                ),
              )),
        if (timeSlots.isNotEmpty) const _CurrentTimeIndicator(),
      ],
    );
  }
}

class _TodayCourseItem extends StatelessWidget {
  final Course course;
  final List<TimeSlot> timeSlots;
  final VoidCallback onTap;

  const _TodayCourseItem({
    required this.course,
    required this.timeSlots,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = intToColor(course.colorValue);

    String timeText = '';
    if (course.startPeriod <= timeSlots.length &&
        course.endPeriod <= timeSlots.length) {
      timeText =
          '${timeSlots[course.startPeriod - 1].startTime} - ${timeSlots[course.endPeriod - 1].endTime}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm + 2),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [course.room, course.teacher]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              if (course.weekType != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    weekTypeNames[course.weekType],
                    style: TextStyle(
                      fontSize: 10,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentTimeIndicator extends StatefulWidget {
  const _CurrentTimeIndicator();

  @override
  State<_CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<_CurrentTimeIndicator> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<ScheduleProvider>();
    final timeSlots = provider.timeSlots;
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;

    int? currentPeriod;
    double progress = 0;

    for (int i = 0; i < timeSlots.length; i++) {
      final start = _parseMinutes(timeSlots[i].startTime);
      final end = _parseMinutes(timeSlots[i].endTime);
      if (currentMinutes >= start && currentMinutes < end) {
        currentPeriod = i + 1;
        progress = (currentMinutes - start) / (end - start);
        break;
      }
      if (i < timeSlots.length - 1) {
        final nextStart = _parseMinutes(timeSlots[i + 1].startTime);
        if (currentMinutes >= end && currentMinutes < nextStart) {
          currentPeriod = -1;
          break;
        }
      }
    }

    String status;
    IconData icon;
    if (currentPeriod == null) {
      if (timeSlots.isNotEmpty &&
          currentMinutes < _parseMinutes(timeSlots.first.startTime)) {
        status = '课程尚未开始';
        icon = Icons.hourglass_empty;
      } else {
        status = '今日课程已结束';
        icon = Icons.check_circle_outline;
      }
    } else if (currentPeriod == -1) {
      status = '课间休息';
      icon = Icons.coffee;
    } else {
      status = '第$currentPeriod节课进行中 (${(progress * 100).toInt()}%)';
      icon = Icons.menu_book;
    }

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm + 2),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: Gap.sm),
            Text(
              status,
              style: TextStyle(fontSize: 13, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }

  int _parseMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      debugPrint('Failed to parse time "$time": $e');
      return 0;
    }
  }
}
