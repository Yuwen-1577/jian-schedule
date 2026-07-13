import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/time_utils.dart';

import 'course_detail_sheet.dart';
import 'settings_page.dart';

enum CourseStatus { normal, ongoing, upcoming }

class DayViewPage extends StatefulWidget {
  const DayViewPage({super.key});

  @override
  State<DayViewPage> createState() => _DayViewPageState();
}

class _DayViewPageState extends State<DayViewPage> {
  late DateTime _selectedDate;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    // Page index 1000 is current week
    _pageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  DateTime _mondayForPage(int pageIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    return currentWeekMonday.add(Duration(days: (pageIndex - 1000) * 7));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final cs = Theme.of(context).colorScheme;

    if (!provider.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final weekDayStr = '周${weekdayShortNames[_selectedDate.weekday - 1]}';
    final titleStr = '${_selectedDate.month}月${_selectedDate.day}日 $weekDayStr';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleStr, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '回到今天',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
              _pageController.animateToPage(
                1000,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('设置')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 水平日期选择条 (优化视觉)
          Container(
            height: 75,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                final nextDate = _mondayForPage(
                  index,
                ).add(Duration(days: _selectedDate.weekday - 1));
                if (!nextDate.isAtSameMomentAs(_selectedDate)) {
                  setState(() => _selectedDate = nextDate);
                }
              },
              itemBuilder: (context, index) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final pageMonday = _mondayForPage(index);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (i) {
                    final date = pageMonday.add(Duration(days: i));
                    final isSelected = date.isAtSameMomentAs(_selectedDate);
                    final isToday = date.isAtSameMomentAs(today);

                    return GestureDetector(
                      onTap: () => _onDateSelected(date),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdayShortNames[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? cs.primary
                                  : (isToday
                                        ? cs.primaryContainer.withValues(
                                            alpha: 0.6,
                                          )
                                        : Colors.transparent),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? cs.onPrimary
                                    : (isToday ? cs.primary : cs.onSurface),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          // 时间轴主体
          Expanded(
            child: _TimelineView(date: _selectedDate, provider: provider),
          ),
        ],
      ),
    );
  }
}

class _TimelineView extends StatefulWidget {
  final DateTime date;
  final ScheduleProvider provider;

  const _TimelineView({required this.date, required this.provider});

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView> {
  static const double hourHeight = 85.0; // 稍微拉开一点间距
  static const double timeColumnWidth = 50.0;

  int _startHour = 8;
  int _endHour = 22;

  Timer? _timer;
  late ScrollController _scrollController;
  late String _timeSlotsSignature;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _timeSlotsSignature = _buildTimeSlotsSignature();
    _calculateHours();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final now = TimeOfDay.now();
      final offset =
          ((now.hour * 60 + now.minute) - _startHour * 60) * hourHeight / 60.0;
      final target = (offset - 100).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
    });
  }

  @override
  void didUpdateWidget(_TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _buildTimeSlotsSignature();
    if (signature != _timeSlotsSignature) {
      _timeSlotsSignature = signature;
      _calculateHours();
    }
  }

  String _buildTimeSlotsSignature() {
    return widget.provider.timeSlots
        .map((slot) => '${slot.period}:${slot.startTime}-${slot.endTime}')
        .join('|');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    final now = DateTime.now();
    final msUntilNextMinute = 60000 - (now.second * 1000 + now.millisecond);
    Future.delayed(Duration(milliseconds: msUntilNextMinute), () {
      if (!mounted) return;
      setState(() {});
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  void _calculateHours() {
    final timeSlots = widget.provider.timeSlots;
    if (timeSlots.isNotEmpty) {
      final startMin = TimeUtils.parseMinutes(timeSlots.first.startTime);
      final endMin = TimeUtils.parseMinutes(timeSlots.last.endTime);
      _startHour = (startMin / 60).floor().clamp(0, 24);
      _endHour = (endMin / 60).ceil().clamp(0, 24);
      if (_startHour > 0) _startHour--;
      if (_endHour < 24) _endHour++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.provider.getCoursesForDate(widget.date);
    final cs = Theme.of(context).colorScheme;
    final isToday = widget.date.isAtSameMomentAs(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    if (courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.free_breakfast,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            const SizedBox(height: Gap.md),
            Text(
              '今天没有课程，享受休息吧！',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final totalHours = _endHour - _startHour;
    final totalHeight = totalHours * hourHeight;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 100), // 为底部悬浮按钮留出空间
      child: Stack(
        children: [
          // 时间背景线和刻度
          SizedBox(
            height: totalHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: timeColumnWidth,
                  child: Stack(
                    children: List.generate(totalHours, (i) {
                      return Positioned(
                        top: i * hourHeight,
                        right: Gap.sm,
                        child: FractionalTranslation(
                          translation: const Offset(0, -0.5),
                          child: Text(
                            '${_startHour + i}:00',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: List.generate(totalHours, (i) {
                      return Positioned(
                        top: i * hourHeight,
                        left: 0,
                        right: 0,
                        child: Divider(
                          height: 1,
                          thickness: 0.3,
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // 课程卡片
          Positioned.fill(
            left: timeColumnWidth,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final positionedCourses = _calculateCoursePositions(
                  courses,
                  constraints.maxWidth,
                  isToday,
                );
                return Stack(children: positionedCourses);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _calculateCoursePositions(
    List<Course> courses,
    double availableWidth,
    bool isToday,
  ) {
    if (courses.isEmpty) return [];

    final timeSlots = widget.provider.timeSlots;
    if (timeSlots.isEmpty) return [];

    final List<_CourseBlock> blocks = [];
    for (final course in courses) {
      if (course.startPeriod <= timeSlots.length &&
          course.endPeriod <= timeSlots.length) {
        final startMin = TimeUtils.parseMinutes(
          timeSlots[course.startPeriod - 1].startTime,
        );
        final endMin = TimeUtils.parseMinutes(
          timeSlots[course.endPeriod - 1].endTime,
        );
        blocks.add(_CourseBlock(course, startMin, endMin));
      }
    }

    blocks.sort((a, b) => a.startMin.compareTo(b.startMin));

    List<List<_CourseBlock>> groups = [];
    List<_CourseBlock> currentGroup = [];
    int currentGroupEnd = 0;

    for (final block in blocks) {
      if (currentGroup.isEmpty) {
        currentGroup.add(block);
        currentGroupEnd = block.endMin;
      } else {
        if (block.startMin < currentGroupEnd) {
          currentGroup.add(block);
          if (block.endMin > currentGroupEnd) {
            currentGroupEnd = block.endMin;
          }
        } else {
          groups.add(currentGroup);
          currentGroup = [block];
          currentGroupEnd = block.endMin;
        }
      }
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    List<Widget> widgets = [];
    final startMinutes = _startHour * 60;

    final nowTime = TimeOfDay.now();
    final currentMinutes = nowTime.hour * 60 + nowTime.minute;

    for (final group in groups) {
      List<List<_CourseBlock>> columns = [];
      for (final block in group) {
        bool placed = false;
        for (var col in columns) {
          if (block.startMin >= col.last.endMin) {
            col.add(block);
            placed = true;
            break;
          }
        }
        if (!placed) {
          columns.add([block]);
        }
      }

      final numCols = columns.length;
      final cardWidth = availableWidth / numCols;

      for (int c = 0; c < numCols; c++) {
        for (final block in columns[c]) {
          final top = (block.startMin - startMinutes) * hourHeight / 60.0;
          final height = (block.endMin - block.startMin) * hourHeight / 60.0;
          final left = c * cardWidth;

          CourseStatus status = CourseStatus.normal;
          if (isToday) {
            if (currentMinutes >= block.startMin &&
                currentMinutes < block.endMin) {
              status = CourseStatus.ongoing;
            } else if (block.startMin > currentMinutes &&
                (block.startMin - currentMinutes) <= 30) {
              status = CourseStatus.upcoming;
            }
          }

          widgets.add(
            Positioned(
              top: top,
              left: left,
              width: cardWidth,
              height: height,
              child: _DayCourseCard(
                course: block.course,
                startTime: widget
                    .provider
                    .timeSlots[block.course.startPeriod - 1]
                    .startTime,
                endTime: widget
                    .provider
                    .timeSlots[block.course.endPeriod - 1]
                    .endTime,
                status: status,
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }
}

class _CourseBlock {
  final Course course;
  final int startMin;
  final int endMin;

  _CourseBlock(this.course, this.startMin, this.endMin);
}

class _DayCourseCard extends StatefulWidget {
  final Course course;
  final String startTime;
  final String endTime;
  final CourseStatus status;

  const _DayCourseCard({
    required this.course,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  @override
  State<_DayCourseCard> createState() => _DayCourseCardState();
}

class _DayCourseCardState extends State<_DayCourseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _glowAnimation = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.status == CourseStatus.ongoing) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_DayCourseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == CourseStatus.ongoing &&
        oldWidget.status != CourseStatus.ongoing) {
      _glowController.repeat(reverse: true);
    } else if (widget.status != CourseStatus.ongoing &&
        oldWidget.status == CourseStatus.ongoing) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final baseColor = intToColor(widget.course.colorValue);

    // 基础颜色增强饱和度
    final bgColor = isDark
        ? baseColor.withValues(alpha: 0.25)
        : baseColor.withValues(alpha: 0.15);

    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.95)
        : cs.onSurface;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;

    Widget cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          children: [
            // 左侧色条
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: baseColor),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, Gap.sm, Gap.sm, Gap.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.course.room.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.course.room}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (widget.course.teacher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.course.teacher,
                      style: TextStyle(fontSize: 11, color: subTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    '${widget.startTime} - ${widget.endTime}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 状态标签
            if (widget.status != CourseStatus.normal)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.status == CourseStatus.ongoing
                        ? baseColor
                        : baseColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.status == CourseStatus.ongoing ? '正在进行' : '即将开始',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: widget.status == CourseStatus.ongoing
                          ? Colors.white
                          : baseColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // 正在进行：发光边框
    if (widget.status == CourseStatus.ongoing) {
      return GestureDetector(
        onTap: () =>
            CourseDetailBottomSheet.show(context, course: widget.course),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: _glowAnimation.value),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: cardContent,
        ),
      );
    }

    // 即将开始：虚线边框
    if (widget.status == CourseStatus.upcoming) {
      return GestureDetector(
        onTap: () =>
            CourseDetailBottomSheet.show(context, course: widget.course),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: baseColor),
          child: cardContent,
        ),
      );
    }

    // 正常状态
    return GestureDetector(
      onTap: () => CourseDetailBottomSheet.show(context, course: widget.course),
      child: cardContent,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 1, size.width - 8, size.height - 2),
      const Radius.circular(AppRadius.sm),
    );
    path.addRRect(rrect);

    const dashWidth = 5.0;
    const dashSpace = 5.0;
    var distance = 0.0;

    for (PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        final extractPath = measurePath.extractPath(
          distance,
          distance + dashWidth,
        );
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
