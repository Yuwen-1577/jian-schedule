import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../pages/course_edit_page.dart';
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

    if (timeSlots.isEmpty) {
      return const Center(child: Text('请先设置上课时间'));
    }

    final periodHeight = ScheduleDim.periodHeight;
    final availWidth = MediaQuery.of(context).size.width - ScheduleDim.timeColumnWidth;

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
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday;

    return Container(
      height: ScheduleDim.dayHeaderHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
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
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    )
                  : null,
              child: Text(
                weekdayNames[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  color: isToday ? cs.primary : cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    final totalHeight = periodHeight * timeSlots.length;
    final colWidth = availWidth / days;
    final borderColor = cs.outlineVariant;

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
      final placements = calculatePlacements(dayCourses);

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

  void _onCourseTap(BuildContext context, Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CourseEditPage(),
        settings: RouteSettings(arguments: course),
      ),
    );
  }

  void _onCourseLongPress(BuildContext context, Course course) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = intToColor(course.colorValue);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 课程详情卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Gap.lg),
                decoration: BoxDecoration(
                  color: bgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface)),
                    const SizedBox(height: Gap.sm),
                    if (course.room.isNotEmpty)
                      Text('教室: ${course.room}',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    if (course.teacher.isNotEmpty)
                      Text('教师: ${course.teacher}',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    Text(
                      '${weekdayNames[course.day - 1]} 第${course.startPeriod}-${course.endPeriod}节 · 第${course.startWeek}-${course.endWeek}周',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourseEditPage(),
                            settings: RouteSettings(arguments: course),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        provider.deleteCourse(course.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已删除「${course.name}」'),
                            action: SnackBarAction(
                              label: '撤销',
                              onPressed: () => provider.addCourse(course),
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                      label: Text('删除', style: TextStyle(color: cs.error)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoursePlacement {
  final Course course;
  final int colOffset;
  final int totalCols;
  const CoursePlacement(this.course, this.colOffset, this.totalCols);
}

@visibleForTesting
bool overlaps(Course a, Course b) {
  return a.startPeriod < b.startPeriod + b.duration &&
      a.startPeriod + a.duration > b.startPeriod;
}

@visibleForTesting
List<CoursePlacement> calculatePlacements(List<Course> courses) {
  if (courses.isEmpty) return [];
  final cols = <int, List<Course>>{};

  for (final c in courses) {
    int col = 0;
    while (true) {
      cols.putIfAbsent(col, () => []);
      final hasOverlap = cols[col]!.any((e) => overlaps(c, e));
      if (!hasOverlap) {
        cols[col]!.add(c);
        break;
      }
      col++;
    }
  }

  final result = <CoursePlacement>[];
  final total = cols.length;
  for (final e in cols.entries) {
    for (final c in e.value) {
      result.add(CoursePlacement(c, e.key, total));
    }
  }
  return result;
}
