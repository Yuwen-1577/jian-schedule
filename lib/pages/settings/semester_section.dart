import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schedule_provider.dart';
import 'settings_widgets.dart';

class SemesterSection extends StatelessWidget {
  const SemesterSection({super.key});

  void _pickSemesterStart(
    BuildContext context,
    ScheduleProvider provider,
  ) async {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final actualTeachingWeek = provider.actualTeachingWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '学期设置'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.date_range),
            title: const Text('学期开始日期'),
            subtitle: Text(
              '${provider.semesterStart.year}年${provider.semesterStart.month}月${provider.semesterStart.day}日',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () => _pickSemesterStart(context, provider),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.today),
            title: const Text('当前教学周'),
            subtitle: Text(
              actualTeachingWeek == null
                  ? '当前日期不在本学期内'
                  : '第 $actualTeachingWeek 周',
            ),
            trailing: const Text('自动计算'),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
