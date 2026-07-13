import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/time_slot.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../pages/course_edit_page.dart'; // Contains CourseEditBottomSheet
import '../pages/course_detail_sheet.dart';
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

    const periodHeight = ScheduleDim.periodHeight;
    final availWidth =
        MediaQuery.of(context).size.width - ScheduleDim.timeColumnWidth;

    final semesterStart = provider.semesterStart;
    final monday = semesterStart.add(Duration(days: (week - 1) * 7));
    final month = monday.month;

    return Column(
      children: [
        // 固定的顶部表头
        Row(
          children: [
            _CornerHeader(month: month),
            Expanded(child: _DayHeader(days: days)),
          ],
        ),
        // 可随主体滚动的课表与时间轴
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimeColumn(timeSlots: timeSlots, periodHeight: periodHeight),
                Expanded(
                  child: SizedBox(
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerHeader extends StatelessWidget {
  final int month;
  const _CornerHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: ScheduleDim.timeColumnWidth,
      height: ScheduleDim.dayHeaderHeight,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$month月',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
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

class _GridBody extends StatefulWidget {
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
  State<_GridBody> createState() => _GridBodyState();
}

class _GridBodyState extends State<_GridBody> {
  int? _dragDay;
  int? _dragStartPeriod;
  int? _dragEndPeriod;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalHeight = widget.periodHeight * widget.timeSlots.length;
    final colWidth = widget.availWidth / widget.days;
    final borderColor = cs.outlineVariant;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 水平网格线
          ...List.generate(widget.timeSlots.length, (row) {
            return Positioned(
              top: row * widget.periodHeight,
              left: 0,
              right: 0,
              height: widget.periodHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),

          // 铺满网格用于接收拖拽事件 (创建新课程 或 接收卡片拖放)
          Positioned.fill(
            child: Row(
              children: List.generate(widget.days, (col) {
                final d = col + 1;
                return Expanded(
                  child: DragTarget<Course>(
                    onWillAcceptWithDetails: (details) => true,
                    onAcceptWithDetails: (details) async {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localOffset = box.globalToLocal(details.offset);
                      // Adjust dy to map to period
                      final droppedStartPeriod =
                          (localOffset.dy / widget.periodHeight).floor() + 1;
                      final course = details.data;

                      final s = droppedStartPeriod.clamp(
                        1,
                        widget.timeSlots.length - course.duration + 1,
                      );
                      if (course.day == d && course.startPeriod == s) return;

                      final newCourse = course.copyWith(
                        day: d,
                        startPeriod: s,
                        activeWeeks: List.from(course.activeWeeks),
                      );

                      final dayCourses = widget.provider
                          .getCoursesForDay(widget.week, d)
                          .where((c) => c.id != course.id)
                          .toList();
                      final hasConflict = dayCourses.any(
                        (c) => overlaps(c, newCourse),
                      );

                      if (hasConflict) {
                        final allow = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('课程时间冲突'),
                            content: const Text('您拖放的时间段已经有课程了。是否继续创建并形成堆叠卡片？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.primary,
                                ),
                                child: const Text('继续'),
                              ),
                            ],
                          ),
                        );
                        if (allow != true) return;
                      }

                      widget.provider.updateCourse(newCourse);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (details) {
                          setState(() {
                            _dragDay = d;
                            _dragStartPeriod =
                                (details.localPosition.dy / widget.periodHeight)
                                    .floor() +
                                1;
                            _dragEndPeriod = _dragStartPeriod;
                          });
                        },
                        onLongPressMoveUpdate: (details) {
                          if (_dragDay == d && _dragStartPeriod != null) {
                            setState(() {
                              final period =
                                  (details.localPosition.dy /
                                          widget.periodHeight)
                                      .floor() +
                                  1;
                              _dragEndPeriod = period.clamp(
                                _dragStartPeriod!,
                                widget.timeSlots.length,
                              );
                            });
                          }
                        },
                        onLongPressEnd: (details) async {
                          if (_dragDay != d ||
                              _dragStartPeriod == null ||
                              _dragEndPeriod == null) {
                            return;
                          }

                          final s = _dragStartPeriod!;
                          final e = _dragEndPeriod!;
                          final duration = e - s + 1;

                          setState(() {
                            _dragDay = null;
                            _dragStartPeriod = null;
                            _dragEndPeriod = null;
                          });

                          final newCourse = Course(
                            id: '',
                            name: '',
                            room: '',
                            teacher: '',
                            day: d,
                            startPeriod: s,
                            duration: duration,
                            activeWeeks: [widget.week],
                            colorValue: 0,
                            note: '',
                            scheduleSetId: '',
                          );
                          final dayCourses = widget.provider.getCoursesForDay(
                            widget.week,
                            d,
                          );
                          final hasConflict = dayCourses.any(
                            (c) => overlaps(c, newCourse),
                          );

                          if (hasConflict) {
                            final allow = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('课程时间冲突'),
                                content: const Text(
                                  '您选中的时间段已经有课程了。是否继续创建并形成堆叠卡片？',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.primary,
                                    ),
                                    child: const Text('继续'),
                                  ),
                                ],
                              ),
                            );
                            if (allow != true) return;
                          }

                          if (context.mounted) {
                            CourseEditBottomSheet.show(
                              context,
                              day: d,
                              startPeriod: s,
                              duration: duration,
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            if (_dragDay == d &&
                                _dragStartPeriod != null &&
                                _dragEndPeriod != null)
                              Positioned(
                                top:
                                    (_dragStartPeriod! - 1) *
                                    widget.periodHeight,
                                left: 2,
                                right: 2,
                                height:
                                    (_dragEndPeriod! - _dragStartPeriod! + 1) *
                                    widget.periodHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: cs.primary.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),

          // 课程卡片 (分组渲染，支持横滑切牌)
          ..._buildCourseCards(context, colWidth),
        ],
      ),
    );
  }

  List<Widget> _buildCourseCards(BuildContext context, double colWidth) {
    final widgets = <Widget>[];

    for (int d = 1; d <= widget.days; d++) {
      final dayCourses = widget.provider.getCoursesForDay(widget.week, d);
      if (dayCourses.isEmpty) continue;

      final placements = calculatePlacements(dayCourses);
      final groups = _groupPlacements(placements);

      for (final group in groups) {
        widgets.add(
          Positioned(
            left: (d - 1) * colWidth + 2.0,
            top: 0,
            bottom: 0,
            width: colWidth - 4.0,
            child: _StackedCourseGroup(
              group: group,
              colWidth: colWidth,
              periodHeight: widget.periodHeight,
              parentContext: context,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<List<CoursePlacement>> _groupPlacements(
    List<CoursePlacement> placements,
  ) {
    if (placements.isEmpty) return [];
    final sorted = List<CoursePlacement>.from(placements)
      ..sort((a, b) => a.course.startPeriod.compareTo(b.course.startPeriod));

    final groups = <List<CoursePlacement>>[];
    List<CoursePlacement> currentGroup = [sorted.first];
    int currentMaxEnd =
        sorted.first.course.startPeriod + sorted.first.course.duration;

    for (int i = 1; i < sorted.length; i++) {
      final p = sorted[i];
      if (p.course.startPeriod < currentMaxEnd) {
        currentGroup.add(p);
        if (p.course.startPeriod + p.course.duration > currentMaxEnd) {
          currentMaxEnd = p.course.startPeriod + p.course.duration;
        }
      } else {
        groups.add(currentGroup);
        currentGroup = [p];
        currentMaxEnd = p.course.startPeriod + p.course.duration;
      }
    }
    groups.add(currentGroup);
    return groups;
  }
}

class _StackedCourseGroup extends StatefulWidget {
  final List<CoursePlacement> group;
  final double colWidth;
  final double periodHeight;
  final BuildContext parentContext;

  const _StackedCourseGroup({
    required this.group,
    required this.colWidth,
    required this.periodHeight,
    required this.parentContext,
  });

  @override
  State<_StackedCourseGroup> createState() => _StackedCourseGroupState();
}

class _StackedCourseGroupState extends State<_StackedCourseGroup> {
  int _topIndex = 0;

  @override
  void didUpdateWidget(covariant _StackedCourseGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_topIndex >= widget.group.length) {
      _topIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<CoursePlacement>.from(widget.group);
    final topP = sorted.removeAt(_topIndex);
    sorted.add(
      topP,
    ); // Put top element at the end of the list so it renders last (on top)

    final width = widget.colWidth - 4.0;

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragEnd: (details) {
        if (widget.group.length <= 1) return;
        if (details.primaryVelocity! > 0) {
          setState(
            () => _topIndex =
                (_topIndex - 1 + widget.group.length) % widget.group.length,
          );
        } else if (details.primaryVelocity! < 0) {
          setState(() => _topIndex = (_topIndex + 1) % widget.group.length);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: sorted.map((p) {
          final isTop = p == topP;
          final leftOffset = isTop ? 0.0 : p.colOffset * 8.0;
          final topOffset = isTop ? 0.0 : p.colOffset * 4.0;
          final scale = isTop ? 1.0 : 0.93;
          final opacity = isTop ? 1.0 : 0.8;

          final top =
              (p.course.startPeriod - 1) * widget.periodHeight + topOffset;
          final height = p.course.duration * widget.periodHeight - 2.0;

          return AnimatedPositioned(
            key: ValueKey(p.course.id),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: leftOffset,
            top: top,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              scale: scale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: opacity,
                child: CourseCard(
                  course: p.course,
                  width: width,
                  height: height,
                  stackCount: isTop ? widget.group.length : null,
                  onTap: () {
                    if (!isTop) {
                      setState(() => _topIndex = widget.group.indexOf(p));
                    } else {
                      CourseDetailBottomSheet.show(
                        widget.parentContext,
                        course: p.course,
                      );
                    }
                  },
                ),
              ),
            ),
          );
        }).toList(),
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
