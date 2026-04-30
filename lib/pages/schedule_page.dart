import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/week_grid.dart';
import '../widgets/today_courses.dart';
import '../utils/constants.dart';
import 'course_edit_page.dart';
import 'time_setting_page.dart';
import 'settings_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScheduleProvider>();
    _pageController = PageController(initialPage: provider.currentWeek - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // 回到本周
            _pageController.animateToPage(
              currentWeek - 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Text('第$currentWeek周', style: const TextStyle(fontSize: 20)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加课程',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CourseEditPage(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'time':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TimeSettingPage()),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                  break;
                case 'today':
                  Scaffold.of(context).openEndDrawer();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('今日课程')),
              const PopupMenuItem(value: 'time', child: Text('时间设置')),
              const PopupMenuItem(value: 'settings', child: Text('设置')),
            ],
          ),
        ],
      ),
      // 右侧抽屉：今日课程
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '今日课程',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Expanded(child: TodayCourses()),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 周次快速切换条
          Container(
            height: 36,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: currentWeek > 1
                      ? () {
                          provider.setWeek(currentWeek - 1);
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: 25,
                    controller: ScrollController(
                      initialScrollOffset: (currentWeek - 1) * 48.0,
                    ),
                    itemBuilder: (context, index) {
                      final week = index + 1;
                      final isCurrent = week == currentWeek;
                      return GestureDetector(
                        onTap: () {
                          provider.setWeek(week);
                          _pageController.animateToPage(
                            week - 1,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          width: 42,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$week',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: currentWeek < 25
                      ? () {
                          provider.setWeek(currentWeek + 1);
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
              ],
            ),
          ),
          // 课表视图
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 25,
              onPageChanged: (index) {
                provider.setWeek(index + 1);
              },
              itemBuilder: (context, index) {
                return WeekGrid(week: index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}
