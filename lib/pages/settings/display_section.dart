import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'settings_widgets.dart';

class DisplaySection extends StatelessWidget {
  const DisplaySection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '显示设置'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.weekend),
                title: const Text('显示周末'),
                subtitle: Text(settings.showWeekends ? '显示周六、周日' : '仅显示周一至周五'),
                value: settings.showWeekends,
                onChanged: (v) => settings.setShowWeekends(v),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.font_download_outlined),
                title: const Text('跟随系统字体'),
                subtitle: const Text('停用内置艺术字体，使用系统全局字体'),
                value: settings.useSystemFont,
                onChanged: (v) => settings.setUseSystemFont(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
