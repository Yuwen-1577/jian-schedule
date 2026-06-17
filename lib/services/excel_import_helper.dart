import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/schedule_provider.dart';
import 'xls_import_service.dart';

class ExcelImportHelper {
  static Future<void> importFromExcel(
    BuildContext context,
    ScheduleProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!context.mounted) return;

      // 显示加载中
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final courses = await XlsImportService.parseFile(filePath);

      if (!context.mounted) return;
      Navigator.pop(context); // 关闭加载

      if (courses.isEmpty) {
        _showError(context, '未解析到任何课程，请检查文件格式');
        return;
      }

      // 确认导入
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入 Excel 课表'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('解析到 ${courses.length} 门课程，是否导入到当前课表集？'),
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
                        '导入将追加到当前课表集，同名课程可能产生冲突',
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
              child: const Text('导入'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await provider.importCoursesToActiveSet(courses);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功导入 ${courses.length} 门课程')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 关闭加载（如果还在）
        _showError(context, '导入失败: $e');
      }
    }
  }

  static void _showError(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
