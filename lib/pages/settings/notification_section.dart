import 'package:flutter/material.dart';
import 'settings_widgets.dart';

class NotificationSection extends StatelessWidget {
  const NotificationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '通知设置'),
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
      ],
    );
  }
}
