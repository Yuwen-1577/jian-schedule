import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final provider = context.read<ScheduleProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === 学期设置 ===
          _buildSectionTitle('学期设置'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('学期开始日期'),
              subtitle: Text(
                '${provider.semesterStart.year}年${provider.semesterStart.month}月${provider.semesterStart.day}日',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _pickSemesterStart(provider),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.today),
              title: const Text('当前教学周'),
              subtitle: Text('第 ${provider.currentWeek} 周'),
              trailing: const Text('自动计算'),
            ),
          ),
          const SizedBox(height: 20),

          // === 显示设置 ===
          _buildSectionTitle('显示设置'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.weekend),
                  title: const Text('显示周末'),
                  subtitle:
                      Text(settings.showWeekends ? '显示周六、周日' : '仅显示周一至周五'),
                  value: settings.showWeekends,
                  onChanged: (v) => settings.setShowWeekends(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // === 主题设置 ===
          _buildSectionTitle('主题设置'),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('浅色模式'),
                  secondary: const Icon(Icons.light_mode),
                  value: ThemeMode.light,
                  groupValue: settings.themeMode,
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('深色模式'),
                  secondary: const Icon(Icons.dark_mode),
                  value: ThemeMode.dark,
                  groupValue: settings.themeMode,
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('跟随系统'),
                  secondary: const Icon(Icons.settings_brightness),
                  value: ThemeMode.system,
                  groupValue: settings.themeMode,
                  onChanged: (v) => settings.setThemeMode(v!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // === 数据管理 ===
          _buildSectionTitle('数据管理'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title: const Text('导出课表数据'),
                  subtitle: const Text('导出为 JSON 文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportData(provider),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title: const Text('导入课表数据'),
                  subtitle: const Text('从 JSON 文件导入'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importData(provider),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('清除所有数据',
                      style: TextStyle(color: Colors.red)),
                  subtitle: const Text('将删除所有课程数据'),
                  onTap: () => _clearAllData(provider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // === 关于 ===
          _buildSectionTitle('关于'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('WakeUp课程表'),
                  subtitle: Text('跨平台课表管理工具'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('版本'),
                  subtitle: const Text('v1.0.0'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _pickSemesterStart(ScheduleProvider provider) async {
    final date = await showDatePicker(
      context: context,
      initialDate: provider.semesterStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      provider.setSemesterStart(date);
    }
  }

  void _exportData(ScheduleProvider provider) async {
    try {
      final jsonStr = await provider.exportJson();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('导出成功'),
            content: SizedBox(
              height: 200,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showError('导出失败: $e');
    }
  }

  void _importData(ScheduleProvider provider) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入课表数据'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '请粘贴 JSON 数据...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final result =
                    await provider.importJson(ctrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '导入成功: ${result['coursesCount']} 门课程, ${result['timeSlotsCount']} 个时间段')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('导入失败: $e')),
                  );
                }
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _clearAllData(ScheduleProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('此操作将删除所有课程数据，不可恢复。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final course in List.from(provider.courses)) {
        provider.deleteCourse(course.id);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有数据已清除')),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
