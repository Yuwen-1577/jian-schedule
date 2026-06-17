import 'package:flutter/material.dart';
import 'settings/semester_section.dart';
import 'settings/display_section.dart';
import 'settings/notification_section.dart';
import 'settings/theme_section.dart';
import 'settings/data_section.dart';
import 'settings/ocr_config_section.dart';
import 'settings/about_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SemesterSection(),
          DisplaySection(),
          NotificationSection(),
          ThemeSection(),
          DataSection(),
          OcrConfigSection(),
          AboutSection(),
        ],
      ),
    );
  }
}
