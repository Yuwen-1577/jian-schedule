import 'package:flutter/material.dart';

// 学期预设
const List<String> semesterNames = [
  '大一上学期',
  '大一下学期',
  '大二上学期',
  '大二下学期',
  '大三上学期',
  '大三下学期',
  '大四上学期',
  '大四下学期',
];

// 周几名称
const List<String> weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
const List<String> weekdayShortNames = ['一', '二', '三', '四', '五', '六', '日'];

// 单双周标签
const List<String> weekTypeNames = ['全周', '单周', '双周'];

// 预设课程颜色
const List<int> presetColors = [
  0xFFE57373, // 红色
  0xFFFFB74D, // 橙色
  0xFFFFD54F, // 黄色
  0xFF81C784, // 绿色
  0xFF4FC3F7, // 浅蓝
  0xFF64B5F6, // 蓝色
  0xFF9575CD, // 紫色
  0xFFE57399, // 粉色
  0xFF4DB6AC, // 青色
  0xFF90A4AE, // 灰色
  0xFF7986CB, // 靛蓝
  0xFFA1887F, // 棕色
];

// 颜色转 Color
Color intToColor(int value) => Color(value);

// Color 转 int
int colorToInt(Color color) => color.value;

// 获取颜色亮度，用于决定文字颜色
bool isDarkColor(int colorValue) {
  final color = Color(colorValue);
  final luminance = color.computeLuminance();
  return luminance < 0.5;
}

// 学期开始日期 (默认 2025年2月17日)
DateTime defaultSemesterStart = DateTime(2025, 2, 17);

// 计算当前教学周
int calculateCurrentWeek(DateTime semesterStart) {
  final now = DateTime.now();
  final diff = now.difference(semesterStart).inDays;
  final week = (diff / 7).ceil();
  return week.clamp(1, 25);
}
