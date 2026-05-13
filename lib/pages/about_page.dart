import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          // App 图标和名称
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.schedule,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '简课表',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '跨平台课表管理工具',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withAlpha(128),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'v1.3.1',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 详细信息
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('版本号'),
                  subtitle: const Text('v1.3.1'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('支持平台'),
                  subtitle:
                      const Text('Android / iOS / Windows / Linux / macOS / Web'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('技术栈'),
                  subtitle: const Text('Flutter / Dart'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('数据存储'),
                  subtitle: const Text('本地 SQLite 数据库'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 版权信息
          Center(
            child: Text(
              'Copyright © 2025 简课表',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '开源 · 免费 · 无广告',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
