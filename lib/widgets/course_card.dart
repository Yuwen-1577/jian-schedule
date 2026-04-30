import 'package:flutter/material.dart';
import '../models/course.dart';
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
    final bgColor = intToColor(course.colorValue);
    final useLightText = isDarkColor(course.colorValue);
    final textColor = useLightText ? Colors.white : Colors.black87;

    // 合并教室和教师，节省垂直空间
    String detail = [course.room, course.teacher]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: bgColor.withAlpha(80),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (detail.isNotEmpty)
              Text(
                detail,
                style: TextStyle(
                  fontSize: 9,
                  color: textColor.withAlpha(200),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
