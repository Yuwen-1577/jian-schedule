import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
import 'database_service.dart';

class ExportService {
  final DatabaseService _db = DatabaseService();

  // 导出到文件
  Future<String> exportToFile() async {
    final jsonStr = await _db.exportToJson();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final filePath = join(dir.path, 'schedule_backup_$timestamp.json');
    final file = File(filePath);
    await file.writeAsString(jsonStr);
    return filePath;
  }

  // 从文件导入
  Future<Map<String, dynamic>> importFromFile(String filePath) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    return await _db.importFromJson(jsonStr);
  }

  // 获取导出 JSON 字符串 (用于分享)
  Future<String> getExportJson() async {
    return await _db.exportToJson();
  }

  // 从 JSON 字符串导入
  Future<Map<String, dynamic>> importFromJson(String jsonStr) async {
    return await _db.importFromJson(jsonStr);
  }

  // 避免 path_provider 未安装时报错，提供 fallback
  static Future<String> getExportPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (e) {
      return Directory.current.path;
    }
  }
}
