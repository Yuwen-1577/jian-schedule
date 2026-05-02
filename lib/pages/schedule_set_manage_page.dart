import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../models/schedule_set.dart';

class ScheduleSetManagePage extends StatelessWidget {
  const ScheduleSetManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final sets = provider.scheduleSets;

    return Scaffold(
      appBar: AppBar(title: const Text('管理课表集')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sets.length,
        itemBuilder: (context, index) {
          final set = sets[index];
          final isActive = set.id == provider.activeSetId;
          return Card(
            child: ListTile(
              leading: isActive
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : const Icon(Icons.schedule),
              title: Text(
                set.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${set.semesterStart.year}年${set.semesterStart.month}月${set.semesterStart.day}日开始',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _renameSet(context, provider, set),
                  ),
                  if (sets.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                      onPressed: () => _deleteSet(context, provider, set),
                    ),
                ],
              ),
              onTap: isActive ? null : () => provider.switchSet(set.id),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createSet(context, provider),
        tooltip: '新建课表集',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _createSet(BuildContext context, ScheduleProvider provider) async {
    final ctrl = TextEditingController(text: '未命名课表集${provider.scheduleSets.length + 1}');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建课表集'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '课表集名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (result == true && ctrl.text.trim().isNotEmpty) {
      final newSet = await provider.createSet(ctrl.text.trim());
      await provider.switchSet(newSet.id);
    }
  }

  void _renameSet(
      BuildContext context, ScheduleProvider provider, ScheduleSet set) async {
    final ctrl = TextEditingController(text: set.name);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名课表集'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '课表集名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == true && ctrl.text.trim().isNotEmpty) {
      await provider.renameSet(set.id, ctrl.text.trim());
    }
  }

  void _deleteSet(
      BuildContext context, ScheduleProvider provider, ScheduleSet set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除课表集'),
        content: Text('确定删除「${set.name}」？该课表集下的所有课程也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteSet(set.id);
    }
  }
}
