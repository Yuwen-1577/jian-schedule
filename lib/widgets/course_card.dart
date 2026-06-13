import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class CourseCard extends StatelessWidget {
  final Course course;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final int? stackCount;

  const CourseCard({
    super.key,
    required this.course,
    required this.width,
    required this.height,
    this.onTap,
    this.stackCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    final baseColor = intToColor(course.colorValue);
    final bgColor = isDark
        ? baseColor.withValues(alpha: 0.35)
        : baseColor.withValues(alpha: 0.85);
    final accentColor = baseColor;

    final textColor = isDark ? Colors.white.withValues(alpha: 0.92) : cs.onSurface;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : cs.onSurfaceVariant;

    return LongPressDraggable<Course>(
      data: course,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: _buildCardContent(context, isDark, bgColor, accentColor, textColor, subTextColor),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(context, isDark, bgColor, accentColor, textColor, subTextColor),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _buildCardContent(context, isDark, bgColor, accentColor, textColor, subTextColor),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, bool isDark, Color bgColor, Color accentColor, Color textColor, Color subTextColor) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ScheduleDim.courseCardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.white.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          course.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (course.room.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '@${course.room}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: textColor.withValues(alpha: 0.9),
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (course.teacher.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            course.teacher,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.normal,
                              color: subTextColor,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (stackCount != null && stackCount! > 1)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        '$stackCount',
                        style: TextStyle(
                          fontSize: 9, 
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
