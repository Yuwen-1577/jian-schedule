import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import 'settings_widgets.dart';

class ThemeSection extends StatelessWidget {
  const ThemeSection({super.key});

  void _pickCustomSeedColor(BuildContext context, SettingsProvider settings) {
    Color pickerColor = settings.seedColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择主题色'),
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
              settings.setSeedColor(pickerColor);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '主题设置'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                  label: Text('浅色'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                  label: Text('深色'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_brightness, size: 18),
                  label: Text('跟随系统'),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => settings.setThemeMode(v.first),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle(title: '主题色'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in seedColors)
                      Semantics(
                        button: true,
                        selected:
                            settings.seedColor.toARGB32() == color.toARGB32(),
                        label: '主题色 ${seedColors.indexOf(color) + 1}',
                        child: InkResponse(
                          onTap: () => settings.setSeedColor(color),
                          radius: 24,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border:
                                  settings.seedColor.toARGB32() ==
                                      color.toARGB32()
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: [
                                if (settings.seedColor.toARGB32() ==
                                    color.toARGB32())
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                              ],
                            ),
                            child:
                                settings.seedColor.toARGB32() ==
                                    color.toARGB32()
                                ? Icon(
                                    Icons.check,
                                    color: isDarkColor(color.toARGB32())
                                        ? Colors.white
                                        : Colors.black,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    // 自定义颜色按钮
                    Semantics(
                      button: true,
                      selected: !seedColors.any(
                        (color) =>
                            color.toARGB32() == settings.seedColor.toARGB32(),
                      ),
                      label: '自定义主题色',
                      child: InkResponse(
                        onTap: () => _pickCustomSeedColor(context, settings),
                        radius: 24,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.palette,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
