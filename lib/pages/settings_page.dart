import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../services/xls_import_service.dart';
import '../services/ocr_import_service.dart';
import '../utils/constants.dart';
import 'about_page.dart';

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

          // === 通知设置 ===
          _buildSectionTitle('通知设置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('课程提醒'),
                  subtitle: const Text('在每门课程的编辑页面中设置提前提醒时间'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('课程提醒说明'),
                        content: const Text(
                          '每门课程可独立设置提醒时间（5分钟~1小时前）。\n\n'
                          '提醒会在每次打开应用时自动调度当前周的通知。\n\n'
                          '在课程编辑页面的"上课提醒"选项中设置。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // === 主题设置 ===
          _buildSectionTitle('主题设置'),
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

          // === 主题色 ===
          _buildSectionTitle('主题色'),
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
                        GestureDetector(
                          onTap: () => settings.setSeedColor(color),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: settings.seedColor.toARGB32() == color.toARGB32()
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 3)
                                  : null,
                              boxShadow: [
                                if (settings.seedColor.toARGB32() == color.toARGB32())
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                              ],
                            ),
                            child: settings.seedColor.toARGB32() == color.toARGB32()
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 20)
                                : null,
                          ),
                        ),
                      // 自定义颜色按钮
                      GestureDetector(
                        onTap: () => _pickCustomSeedColor(settings),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline,
                                width: 1.5),
                          ),
                          child: Icon(Icons.palette,
                              size: 20,
                              color:
                                  Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // === 数据管理 ===
          _buildSectionTitle('数据管理'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.widgets_outlined),
                  title: const Text('桌面小部件'),
                  subtitle: const Text('将课表添加到手机桌面'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('请长按桌面 → 添加小部件 → 搜索简课表'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
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
                  leading: const Icon(Icons.table_chart),
                  title: const Text('从 Excel 导入'),
                  subtitle: const Text('支持 .xlsx 格式课表文件'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importFromExcel(provider),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('从截图导入 (OCR)'),
                  subtitle: const Text('支持智能识别课表截图并导入'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importFromOcr(provider, settings),
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

          // === OCR 大模型配置 ===
          _buildSectionTitle('OCR 大模型配置'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline, color: Colors.blue),
                  title: const Text('如何获取免费的 API Key？', style: TextStyle(color: Colors.blue)),
                  onTap: () => _showApiTutorial(context),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('API Base URL'),
                  subtitle: Text(settings.ocrApiUrl.isEmpty ? '未设置' : settings.ocrApiUrl),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _editOcrConfig('API Base URL', settings.ocrApiUrl, settings.setOcrApiUrl),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('API Key'),
                  subtitle: Text(settings.ocrApiKey.isEmpty ? '未设置' : '••••••••'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _editOcrConfig('API Key', settings.ocrApiKey, settings.setOcrApiKey, isPassword: true),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Model Name'),
                  subtitle: Text(settings.ocrModelName),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _editOcrConfig('Model Name', settings.ocrModelName, settings.setOcrModelName),
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
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('简课表'),
                  subtitle: const Text('跨平台课表管理工具'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('版本'),
                  subtitle: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '...';
                      return Text('v$version');
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
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

  void _pickCustomSeedColor(SettingsProvider settings) {
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

  void _pickSemesterStart(ScheduleProvider provider) async {
    final date = await showDatePicker(
      context: context,
      initialDate: provider.semesterStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null) {
      await provider.setSemesterStart(date);
    }
  }

  void _exportData(ScheduleProvider provider) async {
    try {
      final jsonStr = await provider.exportJson();
      if (!mounted) return;

      // 保存到文件
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = p.join(dir.path, 'schedule_backup_$timestamp.json');
      final file = File(filePath);
      await file.writeAsString(jsonStr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出到: $filePath')),
        );
      }
    } catch (e) {
      _showError('导出失败: $e');
    }
  }

  void _importData(ScheduleProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!mounted) return;

      // 读取文件
      final file = File(filePath);
      if (!await file.exists()) {
        _showError('文件不存在');
        return;
      }
      final jsonStr = await file.readAsString();

      // 预览：解析 JSON 展示信息
      final confirmed = await _showImportPreview(jsonStr);
      if (confirmed != true) return;

      if (!mounted) return;

      // 执行导入
      final importResult = await provider.importJson(jsonStr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '导入成功: ${importResult['coursesCount'] ?? 0} 门课程, '
                  '${importResult['setsCount'] ?? 0} 个课表集')),
        );
      }
    } catch (e) {
      _showError('导入失败: $e');
    }
  }

  /// 显示导入预览弹窗
  Future<bool?> _showImportPreview(String jsonStr) async {
    try {
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;
      final version = decoded['version'] ?? '1.0';
      final courses = decoded['courses'] as List? ?? [];
      final sets = decoded['scheduleSets'] as List? ?? [];
      final coursesCount = courses.length;
      final setsCount = sets.length;
      // 提取前 5 门课程名
      final courseNames = courses
          .take(5)
          .map((c) => (c as Map<String, dynamic>)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      if (!mounted) return false;

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
                const Text('课程预览:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                for (final name in courseNames)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('• $name'),
                  ),
                if (courses.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('... 等共 ${courses.length} 门',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
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
                    const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '导入将替换当前所有数据',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[800]),
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
      _showError('JSON 格式错误，无法预览: $e');
      return false;
    }
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
      await provider.clearAllCourses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有数据已清除')),
        );
      }
    }
  }

  void _importFromExcel(ScheduleProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!mounted) return;

      // 显示加载中
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final courses = await XlsImportService.parseFile(filePath);

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载

      if (courses.isEmpty) {
        _showError('未解析到任何课程，请检查文件格式');
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
                    const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '导入将追加到当前课表集，同名课程可能产生冲突',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 ${courses.length} 门课程')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载（如果还在）
        _showError('导入失败: $e');
      }
    }
  }

  void _importFromOcr(ScheduleProvider provider, SettingsProvider settings) async {
    try {
      if (settings.ocrApiKey.isEmpty) {
        _showError('请先配置 OCR 大模型 API Key');
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      if (!mounted) return;

      showDialog(
        context: context,
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

      final courses = await OcrImportService.parseImage(
        filePath,
        settings.ocrApiUrl,
        settings.ocrApiKey,
        settings.ocrModelName,
      );

      if (!mounted) return;
      Navigator.pop(context); // 关闭加载

      if (courses.isEmpty) {
        _showError('未识别到任何课程');
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
        await provider.importCoursesToActiveSet(courses);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功导入 ${courses.length} 门课程')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载（如果还在）
        _showError('识别失败: $e');
      }
    }
  }

  void _editOcrConfig(String title, String initialValue, Function(String) onSave, {bool isPassword = false}) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改 $title'),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: '请输入 $title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showApiTutorial(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('获取 API Key 教程'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('推荐使用阿里云的【通义千问】，国内访问速度快，表格识别能力极强，且新用户赠送海量免费额度。', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('1. 浏览器访问 dashscope.aliyun.com 并登录（支持支付宝快速登录）。'),
              SizedBox(height: 4),
              Text('2. 在百炼控制台的左侧菜单找到「API-KEY 管理」。'),
              SizedBox(height: 4),
              Text('3. 点击「创建新的 API-KEY」，将生成的一串字符（通常以 sk- 开头）复制下来。'),
              SizedBox(height: 4),
              Text('4. 将这串字符粘贴到下方的「API Key」设置项中。'),
              SizedBox(height: 4),
              Text('5. 默认的 API Base URL 和 Model Name 已经为您预设好兼容阿里模型的参数，无需修改即可直接使用。'),
              SizedBox(height: 16),
              Text('注：如果你使用 OpenAI 或者其他兼容格式的中转站，请对应修改 URL 和模型名称。', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('明白了'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
