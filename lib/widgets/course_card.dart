import 'package:flutter/material.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CourseCard({
    super.key,
    required this.course,
    required this.height,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    // 课程色做背景，暗色模式下降低饱和度
    final baseColor = intToColor(course.colorValue);
    final bgColor = isDark
        ? baseColor.withValues(alpha: 0.25)
        : baseColor.withValues(alpha: 0.15);
    final accentColor = baseColor;

    // 文字颜色跟随背景
    final textColor = isDark ? Colors.white.withValues(alpha: 0.92) : cs.onSurface;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: height,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(ScheduleDim.courseCardRadius),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧色条 + 课程名
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    margin: const EdgeInsets.only(right: 5, top: 1),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (course.room.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            course.room,
                            style: TextStyle(
                              fontSize: 9,
                              color: subTextColor,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
