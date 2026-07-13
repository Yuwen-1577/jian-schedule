import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../providers/schedule_provider.dart';
import '../theme/app_theme.dart';

import 'course_edit_page.dart';

class CourseDetailBottomSheet extends StatelessWidget {
  final Course course;

  const CourseDetailBottomSheet({super.key, required this.course});

  static Future<void> show(BuildContext context, {required Course course}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseDetailBottomSheet(course: course),
    );
  }

  void _copy(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final newCourse = course.copyWith(
      id: const Uuid().v4(),
      name: '${course.name} (副本)',
    );
    provider.addCourse(newCourse);
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制课程')));
  }

  void _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课程'),
        content: const Text('确定要删除这门课程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ScheduleProvider>().deleteCourse(course.id);
      Navigator.pop(context);
    }
  }

  void _edit(BuildContext context) {
    Navigator.pop(context);
    CourseEditBottomSheet.show(context, course: course);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<ScheduleProvider>();
    final timeSlots = provider.timeSlots;

    String timeStr = '';
    if (course.startPeriod >= 1 && course.endPeriod <= timeSlots.length) {
      final start = timeSlots[course.startPeriod - 1].startTime;
      final end = timeSlots[course.endPeriod - 1].endTime;
      timeStr = ' $start-$end';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.xxl * 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: cs.error),
                    onPressed: () => _delete(context),
                    tooltip: '删除',
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_outlined, color: cs.primary),
                    onPressed: () => _copy(context),
                    tooltip: '复制',
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: cs.primary),
                    onPressed: () => _edit(context),
                    tooltip: '编辑',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Gap.xl),

          // Details
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            text: course.formattedWeeks,
            color: cs.primary,
          ),
          const SizedBox(height: Gap.md),
          _DetailRow(
            icon: Icons.access_time_outlined,
            text: '第 ${course.startPeriod}-${course.endPeriod} 节$timeStr',
            color: cs.secondary,
          ),
          if (course.teacher.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _DetailRow(
              icon: Icons.person_outline,
              text: course.teacher,
              color: cs.tertiary,
            ),
          ],
          if (course.room.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _DetailRow(
              icon: Icons.room_outlined,
              text: course.room,
              color: cs.primary,
            ),
          ],
          if (course.note.isNotEmpty) ...[
            const SizedBox(height: Gap.md),
            _DetailRow(
              icon: Icons.notes_outlined,
              text: course.note,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
