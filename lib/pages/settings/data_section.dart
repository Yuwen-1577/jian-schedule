import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../providers/schedule_provider.dart';

import '../../services/excel_import_helper.dart';

import 'settings_widgets.dart';

class DataSection extends StatelessWidget {
  const DataSection({super.key});

  void _exportData(BuildContext context, ScheduleProvider provider) async {
    try {
      final jsonStr = await provider.exportJson();
      if (!context.mounted) return;

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = p.join(dir.path, 'schedule_backup_$timestamp.json');
      final file = File(filePath);
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已导出到: $filePath')));
      }
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, '导出失败: $e');
    }
  }

  void _importData(BuildContext context, ScheduleProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!context.mounted) return;

      final file = File(filePath);
      if (!await file.exists()) {
        if (!context.mounted) return;
        _showError(context, '文件不存在');
        return;
      }
      final jsonStr = await file.readAsString();

      if (!context.mounted) return;
      final confirmed = await _showImportPreview(context, jsonStr);
      if (confirmed != true) return;

      if (!context.mounted) return;

      final importResult = await provider.importJson(jsonStr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入成功: ${importResult['coursesCount'] ?? 0} 门课程, '
              '${importResult['setsCount'] ?? 0} 个课表集',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, '导入失败: $e');
    }
  }

  Future<bool?> _showImportPreview(BuildContext context, String jsonStr) async {
    try {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      final version = decoded['version'] ?? '1.0';
      final courses = decoded['courses'] as List? ?? [];
      final sets = decoded['scheduleSets'] as List? ?? [];
      final coursesCount = courses.length;
      final setsCount = sets.length;
      final courseNames = courses
          .take(5)
          .map((c) => (c as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      if (!context.mounted) return false;

      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入预览'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('版本: $version'),
              const SizedBox(height: 4),
              Text('课程数量: $coursesCount 门'),
              Text('课表集: $setsCount 个'),
              Text('时间段: ${(decoded['timeSlots'] as List?)?.length ?? 0} 个'),
              if (courseNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '课程预览:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                for (final name in courseNames)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• $name'),
                  ),
                if (courses.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      '... 等共 ${courses.length} 门',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '导入将替换当前所有数据',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError(context, 'JSON 格式错误，无法预览: $e');
      return false;
    }
  }

  void _clearAllData(BuildContext context, ScheduleProvider provider) async {
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
      await provider.clearAllCourses();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('所有数据已清除')));
      }
    }
  }


  void _showError(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '数据管理'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导出数据'),
                subtitle: const Text('将所有数据导出为 JSON 文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportData(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导入数据'),
                subtitle: const Text('从 JSON 文件恢复数据 (将覆盖现有数据)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importData(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: const Text('从 Excel 导入'),
                subtitle: const Text('支持 .xlsx 格式课表文件'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    ExcelImportHelper.importFromExcel(context, provider),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  '清除所有数据',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('清空所有课表集、课程和时间设置'),
                trailing: const Icon(Icons.chevron_right, color: Colors.red),
                onTap: () => _clearAllData(context, provider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
