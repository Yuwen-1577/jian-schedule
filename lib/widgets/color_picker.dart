import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../utils/constants.dart';

class CourseColorPicker extends StatelessWidget {
  final int selectedColor;
  final ValueChanged<int> onColorSelected;

  const CourseColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 检查当前选中颜色是否在预设列表中
    final isPreset = presetColors.contains(selectedColor);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presetColors.map((color) {
          final isSelected = color == selectedColor;
          return GestureDetector(
            onTap: () => onColorSelected(color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: intToColor(color),
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.black, width: 3)
                    : Border.all(color: Colors.grey[300]!, width: 1),
                boxShadow: isSelected
                    ? [BoxShadow(color: intToColor(color).withValues(alpha: 0.31), blurRadius: 6)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }),
        // 自定义颜色按钮
        GestureDetector(
          onTap: () => _pickCustomColor(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              // 如果当前选中的是自定义颜色，显示该颜色
              color: !isPreset ? intToColor(selectedColor) : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: !isPreset
                    ? Colors.black
                    : Colors.grey[400]!,
                width: !isPreset ? 3 : 1.5,
              ),
            ),
            child: !isPreset
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Icon(Icons.palette, size: 18, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  void _pickCustomColor(BuildContext context) {
    Color pickerColor = intToColor(selectedColor);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择课程颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onColorSelected(pickerColor.toARGB32());
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
