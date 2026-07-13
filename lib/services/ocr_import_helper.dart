import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'ocr_import_service.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';

class OcrImportHelper {
  static Future<void> importFromOcr(
    BuildContext context,
    ScheduleProvider provider,
    SettingsProvider settings,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    var loadingOpen = false;
    try {
      if (settings.ocrApiKey.isEmpty) {
        _showError(context, '请先配置 OCR 大模型 API Key');
        return;
      }

      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!context.mounted) return;

      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text("正在调用视觉大模型分析课表结构...")),
            ],
          ),
        ),
      );
      loadingOpen = true;

      final courses = await OcrImportService.parseImage(
        filePath,
        settings.ocrApiUrl,
        settings.ocrApiKey,
        settings.ocrModelName,
      );

      if (loadingOpen && rootNavigator.mounted) {
        rootNavigator.pop();
        loadingOpen = false;
      }
      if (!context.mounted) return;

      if (courses.isEmpty) {
        _showError(context, '未识别到任何课程');
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入截图课表'),
          content: Text('AI 成功识别到 ${courses.length} 门课程，是否追加到当前课表集？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('导入'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final importedCount = await provider.importCoursesToActiveSet(courses);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                importedCount == 0
                    ? '没有发现新课程，已跳过重复数据'
                    : '成功导入 $importedCount 门课程',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (loadingOpen && rootNavigator.mounted) {
        rootNavigator.pop();
        loadingOpen = false;
      }
      if (context.mounted) _showError(context, '识别失败: $e');
    }
  }

  static void _showError(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
