import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/schedule_provider.dart';
import '../services/excel_import_helper.dart';
import '../utils/constants.dart';
import '../widgets/week_grid.dart';
import '../widgets/today_courses.dart';
import 'course_edit_page.dart';
import 'time_setting_page.dart';
import 'settings_page.dart';
import 'schedule_set_manage_page.dart';
import 'edu_import/webview_import_page.dart';
import '../providers/settings_provider.dart';
import '../services/ocr_import_helper.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late PageController _pageController;
  late ScrollController _weekScrollController;
  String? _scheduleContextSignature;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ScheduleProvider>();
    _pageController = PageController(initialPage: provider.currentWeek - 1);
    _weekScrollController = ScrollController(
      initialScrollOffset: (provider.currentWeek - 1) * 48.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _weekScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;
    final now = DateTime.now();

    if (!provider.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _syncPageWithScheduleContext(provider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: false,
        title: GestureDetector(
          onTap: () {
            final realWeek = provider.calculateWeekForDate(DateTime.now());
            provider.setWeek(realWeek);
            _pageController.animateToPage(
              realWeek - 1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            _syncWeekScroll(realWeek);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${now.year}/${now.month}/${now.day}',
                style: const TextStyle(
                  fontFamily: 'LXGWWenKai',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '第$currentWeek周 周${weekdayShortNames[now.weekday - 1]}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (provider.scheduleSets.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.layers_outlined),
              tooltip: '切换课表集',
              onSelected: (id) => provider.switchSet(id),
              itemBuilder: (context) {
                return provider.scheduleSets.map((set) {
                  return PopupMenuItem(
                    value: set.id,
                    child: Row(
                      children: [
                        if (set.id == provider.activeSetId)
                          Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(
                          set.name,
                          style: TextStyle(
                            fontWeight: set.id == provider.activeSetId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加课程',
            onPressed: () async {
              await CourseEditBottomSheet.show(context);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导入课表',
            onSelected: (value) {
              if (value == 'excel') {
                ExcelImportHelper.importFromExcel(context, provider);
              } else if (value == 'webview') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WebviewImportPage()),
                );
              } else if (value == 'ocr') {
                final settings = context.read<SettingsProvider>();
                OcrImportHelper.importFromOcr(context, provider, settings);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'webview',
                child: Text('从教务系统导入 (网页抓取)'),
              ),
              const PopupMenuItem(value: 'ocr', child: Text('从课表截图导入 (智能识别)')),
              const PopupMenuItem(
                value: 'excel',
                child: Text('从 Excel 导入 (.xlsx)'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: '回到当前周',
            onPressed: () {
              final realWeek = provider.calculateWeekForDate(DateTime.now());
              provider.setWeek(realWeek);
              _pageController.animateToPage(
                realWeek - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              _syncWeekScroll(realWeek);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'today') {
                _scaffoldKey.currentState?.openEndDrawer();
              } else if (value == 'time') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TimeSettingPage()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              } else if (value == 'manage_sets') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScheduleSetManagePage(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('今日课程')),
              const PopupMenuItem(value: 'time', child: Text('时间设置')),
              const PopupMenuItem(value: 'settings', child: Text('设置')),
              const PopupMenuItem(value: 'manage_sets', child: Text('管理课表集')),
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
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '今日课程',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                          _syncWeekScroll(currentWeek - 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: maxWeekCount,
                    controller: _weekScrollController,
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
                          _syncWeekScroll(week);
                        },
                        child: Container(
                          width: 42,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
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
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                  onPressed: currentWeek < maxWeekCount
                      ? () {
                          provider.setWeek(currentWeek + 1);
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                          );
                          _syncWeekScroll(currentWeek + 1);
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
              itemCount: maxWeekCount,
              onPageChanged: (index) {
                provider.setWeek(index + 1);
                _syncWeekScroll(index + 1);
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

  void _syncWeekScroll(int week) {
    final target = (week - 1) * 48.0;
    if (_weekScrollController.hasClients) {
      _weekScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  void _syncPageWithScheduleContext(ScheduleProvider provider) {
    final start = provider.semesterStart;
    final signature =
        '${provider.activeSetId}|${start.year}-${start.month}-${start.day}';
    if (_scheduleContextSignature == signature) return;

    _scheduleContextSignature = signature;
    final targetWeek = provider.currentWeek;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduleContextSignature != signature) return;
      if (provider.currentWeek != targetWeek) return;
      if (_pageController.hasClients &&
          _pageController.page?.round() != targetWeek - 1) {
        _pageController.jumpToPage(targetWeek - 1);
      }
      _syncWeekScroll(targetWeek);
    });
  }
}
