import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import 'course_card.dart';
import 'time_column.dart';

class WeekGrid extends StatelessWidget {
  final int week;

  const WeekGrid({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final timeSlots = provider.timeSlots;
    final showWeekends = context.watch<SettingsProvider>().showWeekends;
    final days = showWeekends ? 7 : 5;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (timeSlots.isEmpty) {
      return const Center(child: Text('请先设置上课时间'));
    }

    final periodHeight = 56.0;
    final availWidth = MediaQuery.of(context).size.width - 48;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TimeColumn(timeSlots: timeSlots, periodHeight: periodHeight),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _DayHeader(days: days),
                SizedBox(
                  height: periodHeight * timeSlots.length,
                  child: _GridBody(
                    week: week,
                    days: days,
                    timeSlots: timeSlots,
                    periodHeight: periodHeight,
                    availWidth: availWidth,
                    provider: provider,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final int days;
  const _DayHeader({required this.days});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now().weekday;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.blue[50],
        border: Border(
          bottom: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: List.generate(days, (i) {
          final isToday = today == i + 1;
          return Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(
                      color: Colors.blue.withAlpha(isDark ? 60 : 30),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                weekdayNames[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  color: isToday
                      ? (isDark ? Colors.blue[300] : Colors.blue[700])
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _GridBody extends StatelessWidget {
  final int week;
  final int days;
  final List<TimeSlot> timeSlots;
  final double periodHeight;
  final double availWidth;
  final ScheduleProvider provider;

  const _GridBody({
    required this.week,
    required this.days,
    required this.timeSlots,
    required this.periodHeight,
    required this.availWidth,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalHeight = periodHeight * timeSlots.length;
    final colWidth = availWidth / days;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 水平网格线 + 竖直线
          ...List.generate(timeSlots.length, (row) {
            return Positioned(
              top: row * periodHeight,
              left: 0,
              right: 0,
              height: periodHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  children: List.generate(days, (col) {
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: col < days - 1
                                ? BorderSide(color: borderColor, width: 0.5)
                                : BorderSide.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          }),
          // 课程卡片
          ..._buildCourseCards(context, colWidth),
        ],
      ),
    );
  }

  List<Widget> _buildCourseCards(BuildContext context, double colWidth) {
    final widgets = <Widget>[];
    final courseMap = <int, List<Course>>{};

    for (int d = 1; d <= days; d++) {
      courseMap[d] = provider.getCoursesForDay(week, d);
    }

    for (int d = 1; d <= days; d++) {
      final dayCourses = courseMap[d]!;
      final placements = _calculatePlacements(dayCourses);

      for (final p in placements) {
        final left = (d - 1) * colWidth + p.colOffset * (colWidth / p.totalCols);
        final width = colWidth / p.totalCols - 1;
        final top = (p.course.startPeriod - 1) * periodHeight;
        final height = p.course.duration * periodHeight - 1;

        widgets.add(
          Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: CourseCard(
              course: p.course,
              height: height,
              onTap: () => _onCourseTap(context, p.course),
              onLongPress: () => _onCourseLongPress(context, p.course),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<_Placement> _calculatePlacements(List<Course> courses) {
    if (courses.isEmpty) return [];
    final cols = <int, List<Course>>{};

    for (final c in courses) {
      int col = 0;
      while (true) {
        cols.putIfAbsent(col, () => []);
        final overlaps = cols[col]!.any((e) => _overlaps(c, e));
        if (!overlaps) {
          cols[col]!.add(c);
          break;
        }
        col++;
      }
    }

    final result = <_Placement>[];
    final total = cols.length;
    for (final e in cols.entries) {
      for (final c in e.value) {
        result.add(_Placement(c, e.key, total));
      }
    }
    return result;
  }

  bool _overlaps(Course a, Course b) {
    return a.startPeriod < b.startPeriod + b.duration &&
        a.startPeriod + a.duration > b.startPeriod;
  }

  void _onCourseTap(BuildContext context, Course course) {
    Navigator.pushNamed(context, '/course_edit', arguments: course);
  }

  void _onCourseLongPress(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('操作课程'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (course.room.isNotEmpty) Text('教室: ${course.room}'),
            if (course.teacher.isNotEmpty) Text('教师: ${course.teacher}'),
            Text('${weekdayNames[course.day - 1]} ${course.startPeriod}-${course.endPeriod}节'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/course_edit', arguments: course);
            },
            child: const Text('编辑'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteCourse(course.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

class _Placement {
  final Course course;
  final int colOffset;
  final int totalCols;
  _Placement(this.course, this.colOffset, this.totalCols);
}
