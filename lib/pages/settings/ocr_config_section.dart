import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'settings_widgets.dart';

class OcrConfigSection extends StatelessWidget {
  const OcrConfigSection({super.key});

  void _editOcrConfig(
    BuildContext context,
    String title,
    String initialValue,
    Function(String) onSave, {
    bool isPassword = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修改 $title'),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(hintText: '请输入 $title'),
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
              Text(
                '推荐使用阿里云的【通义千问】，国内访问速度快，表格识别能力极强，且新用户赠送海量免费额度。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('1. 浏览器访问 dashscope.aliyun.com 并登录（支持支付宝快速登录）。'),
              SizedBox(height: 4),
              Text('2. 在百炼控制台的左侧菜单找到「API-KEY 管理」。'),
              SizedBox(height: 4),
              Text('3. 点击「创建新的 API-KEY」，将生成的一串字符（通常以 sk- 开头）复制下来。'),
              SizedBox(height: 4),
              Text('4. 将这串字符粘贴到下方的「API Key」设置项中。'),
              SizedBox(height: 4),
              Text(
                '5. 默认的 API Base URL 和 Model Name 已经为您预设好兼容阿里模型的参数，无需修改即可直接使用。',
              ),
              SizedBox(height: 16),
              Text(
                '注：如果你使用 OpenAI 或者其他兼容格式的中转站，请对应修改 URL 和模型名称。',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'OCR 大模型配置'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline, color: Colors.blue),
                title: const Text(
                  '如何获取免费的 API Key？',
                  style: TextStyle(color: Colors.blue),
                ),
                onTap: () => _showApiTutorial(context),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('API Base URL'),
                subtitle: Text(
                  settings.ocrApiUrl.isEmpty ? '未设置' : settings.ocrApiUrl,
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editOcrConfig(
                  context,
                  'API Base URL',
                  settings.ocrApiUrl,
                  settings.setOcrApiUrl,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('API Key'),
                subtitle: Text(settings.ocrApiKey.isEmpty ? '未设置' : '••••••••'),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editOcrConfig(
                  context,
                  'API Key',
                  settings.ocrApiKey,
                  settings.setOcrApiKey,
                  isPassword: true,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Model Name'),
                subtitle: Text(
                  settings.ocrModelName.isEmpty ? '未设置' : settings.ocrModelName,
                ),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () => _editOcrConfig(
                  context,
                  'Model Name',
                  settings.ocrModelName,
                  settings.setOcrModelName,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
