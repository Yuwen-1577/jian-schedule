import 'package:flutter/material.dart';

// FNV-1a 哈希，将 UUID 字符串转为稳定的 32 位正整数
int stableId(String uuid) {
  int hash = 0x811c9dc5; // FNV offset basis
  for (int i = 0; i < uuid.length; i++) {
    hash ^= uuid.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF; // FNV prime, 32-bit
  }
  return hash & 0x7FFFFFFF; // 确保正数
}

// 周几名称
const List<String> weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const List<String> weekdayShortNames = ['一', '二', '三', '四', '五', '六', '日'];

// 预设课程颜色 (莫兰迪/柔和色系，适合玻璃拟物化)
const List<int> presetColors = [
  0xFFBDB2B0, // 奶茶/暖灰
  0xFFC8D6D1, // 柔和灰绿
  0xFFDCD2C6, // 拿铁色
  0xFFBAC0CA, // 灰蓝
  0xFFD5C4C4, // 藕荷色/浅玫瑰
  0xFFC1D4C7, // 浅薄荷
  0xFFC4B8C1, // 灰紫
  0xFFE5DED5, // 浅米色
  0xFFB9C2B7, // 莫兰迪绿
  0xFFCCC6C0, // 暖沙色
  0xFFC8CAD0, // 烟灰蓝
  0xFFD4CCB8, // 柔和卡其
];

// 颜色转 Color
Color intToColor(int value) => Color(value);

// 获取颜色亮度，用于决定文字颜色
bool isDarkColor(int colorValue) {
  final color = Color(colorValue);
  final luminance = color.computeLuminance();
  return luminance < 0.5;
}

// 学期开始日期 (动态计算：取最近的周一作为默认值)
DateTime get defaultSemesterStart {
  final now = DateTime.now();
  // 往前推到最近的周一
  final daysFromMonday = now.weekday - 1;
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: daysFromMonday));
}

// 计算当前教学周
int calculateCurrentWeek(DateTime semesterStart) {
  final now = DateTime.now();
  final diff = now.difference(semesterStart).inDays;
  final week = (diff / 7).ceil();
  return week.clamp(1, maxWeekCount);
}

// 默认课表集 ID
const String defaultSetId = 'default';

// 推荐主题色（Material 3 种子色）
const List<Color> seedColors = [
  Color(0xFF2196F3), // 蓝色
  Color(0xFF3F51B5), // 靛蓝
  Color(0xFF673AB7), // 深紫
  Color(0xFF9C27B0), // 紫色
  Color(0xFFE91E63), // 粉色
  Color(0xFFF44336), // 红色
  Color(0xFFFF9800), // 橙色
  Color(0xFF4CAF50), // 绿色
  Color(0xFF009688), // 青色
  Color(0xFF607D8B), // 蓝灰
];

// 最大周数
const int maxWeekCount = 25;
