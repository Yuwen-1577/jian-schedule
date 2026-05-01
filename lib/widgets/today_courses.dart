import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';
import '../pages/course_edit_page.dart';
import '../utils/constants.dart';

class TodayCourses extends StatelessWidget {
  const TodayCourses({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final today = DateTime.now().weekday;
    final courses = provider.getCoursesForDay(provider.currentWeek, today);
    final timeSlots = provider.timeSlots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.today, size: 20),
              const SizedBox(width: 8),
              Text(
                '今日课程 (第${provider.currentWeek}周 ${weekdayNames[today - 1]})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (courses.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('今天没有课程~', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...courses.map((course) => _TodayCourseItem(
                course: course,
                timeSlots: timeSlots,
                onTap: () =>
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CourseEditPage(),
                        settings: RouteSettings(arguments: course),
                      ),
                    ),
              )),
        // 当前进度
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
    final bgColor = intToColor(course.colorValue);
    final useLightText = isDarkColor(course.colorValue);

    String timeText = '';
    if (course.startPeriod <= timeSlots.length &&
        course.endPeriod <= timeSlots.length) {
      timeText =
          '${timeSlots[course.startPeriod - 1].startTime} - ${timeSlots[course.endPeriod - 1].endTime}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [course.room, course.teacher].where((s) => s.isNotEmpty).join(' | '),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              if (course.weekType != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: bgColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    weekTypeNames[course.weekType],
                    style: TextStyle(
                      fontSize: 10,
                      color: bgColor,
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

class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
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
          currentPeriod = -1; // 课间
          break;
        }
      }
    }

    String status;
    IconData icon;
    if (currentPeriod == null) {
      status = '今日课程已结束';
      icon = Icons.check_circle_outline;
    } else if (currentPeriod == -1) {
      status = '课间休息';
      icon = Icons.free_breakfast;
    } else {
      status = '第$currentPeriod节课进行中 (${(progress * 100).toInt()}%)';
      icon = Icons.menu_book;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.blue.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(status, style: TextStyle(fontSize: 13, color: Colors.blue[700])),
            ],
          ),
        ),
      ),
    );
  }

  int _parseMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
