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
    final cs = Theme.of(context).colorScheme;
    final isPreset = presetColors.contains(selectedColor);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...presetColors.map((color) {
          final isSelected = color == selectedColor;
          final swatchColor = intToColor(color);
          return Semantics(
            button: true,
            selected: isSelected,
            label: '课程颜色 ${presetColors.indexOf(color) + 1}',
            child: InkResponse(
              onTap: () => onColorSelected(color),
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: swatchColor,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: cs.outline, width: 2.5)
                          : Border.all(color: cs.outlineVariant, width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: swatchColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: isDarkColor(color)
                                ? Colors.white
                                : Colors.black,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
        // 自定义颜色按钮
        Semantics(
          button: true,
          selected: !isPreset,
          label: '自定义课程颜色',
          child: InkResponse(
            onTap: () => _pickCustomColor(context),
            radius: 24,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: !isPreset ? intToColor(selectedColor) : null,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !isPreset ? cs.outline : cs.outlineVariant,
                      width: !isPreset ? 2.5 : 1.5,
                    ),
                  ),
                  child: !isPreset
                      ? Icon(
                          Icons.check,
                          color: isDarkColor(selectedColor)
                              ? Colors.white
                              : Colors.black,
                          size: 18,
                        )
                      : Icon(
                          Icons.palette,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                ),
              ),
            ),
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
