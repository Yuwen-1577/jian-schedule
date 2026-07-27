import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../providers/settings_provider.dart';
import '../services/excel_import_helper.dart';
import '../services/ocr_import_helper.dart';
import '../utils/constants.dart';
import '../widgets/today_courses.dart';
import '../widgets/week_grid.dart';
import 'course_edit_page.dart';
import 'edu_import/strong_wisdom_import_page.dart';
import 'schedule_set_manage_page.dart';
import 'settings_page.dart';
import 'time_setting_page.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PageController _pageController;
  late final ScrollController _weekScrollController;
  String? _scheduleContextSignature;

  @override
  void initState() {
    super.initState();
    final viewedWeek = context.read<ScheduleProvider>().viewedWeek;
    _pageController = PageController(initialPage: viewedWeek - 1);
    _weekScrollController = ScrollController(
      initialScrollOffset: (viewedWeek - 1) * 48.0,
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

    if (!provider.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _syncPageWithScheduleContext(provider);
    final viewedWeek = provider.viewedWeek;
    final actualTeachingWeek = provider.actualTeachingWeek;
    final viewedMonday = provider.semesterStart.add(
      Duration(days: (viewedWeek - 1) * 7),
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        title: _ScheduleTitle(
          provider: provider,
          subtitle: '第$viewedWeek周 · ${_formatWeekRange(viewedMonday)}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加课程',
            onPressed: () => CourseEditBottomSheet.show(context),
          ),
          if (actualTeachingWeek != null && actualTeachingWeek != viewedWeek)
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: '回到当前教学周',
              onPressed: () => _goToWeek(provider, actualTeachingWeek),
            ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) => _handleMenuSelection(value, provider),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'today_courses',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.today_outlined),
                  title: Text('今日课程'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'import_webview',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.language_outlined),
                  title: Text('从教务系统导入'),
                ),
              ),
              PopupMenuItem(
                value: 'import_ocr',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.document_scanner_outlined),
                  title: Text('从课表截图导入'),
                ),
              ),
              PopupMenuItem(
                value: 'import_excel',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.table_view_outlined),
                  title: Text('从 Excel 导入'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'time',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.schedule_outlined),
                  title: Text('时间设置'),
                ),
              ),
              PopupMenuItem(
                value: 'manage_sets',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.layers_outlined),
                  title: Text('管理课表集'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('设置'),
                ),
              ),
            ],
          ),
        ],
      ),
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
                      tooltip: '关闭',
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
          _WeekSelector(
            viewedWeek: viewedWeek,
            actualTeachingWeek: actualTeachingWeek,
            controller: _weekScrollController,
            onSelected: (week) => _goToWeek(provider, week),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: maxWeekCount,
              onPageChanged: (index) {
                provider.setWeek(index + 1);
                _syncWeekScroll(index + 1);
              },
              itemBuilder: (context, index) => WeekGrid(week: index + 1),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuSelection(
    String value,
    ScheduleProvider provider,
  ) async {
    switch (value) {
      case 'today_courses':
        _scaffoldKey.currentState?.openEndDrawer();
        return;
      case 'import_webview':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StrongWisdomImportPage()),
        );
        return;
      case 'import_ocr':
        if (!mounted) return;
        final settings = context.read<SettingsProvider>();
        await OcrImportHelper.importFromOcr(context, provider, settings);
        return;
      case 'import_excel':
        await ExcelImportHelper.importFromExcel(context, provider);
        return;
      case 'time':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TimeSettingPage()),
        );
        return;
      case 'settings':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
        return;
      case 'manage_sets':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScheduleSetManagePage()),
        );
        return;
    }
  }

  void _goToWeek(ScheduleProvider provider, int week) {
    final targetWeek = week.clamp(1, maxWeekCount);
    provider.setWeek(targetWeek);
    if (_pageController.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _pageController.jumpToPage(targetWeek - 1);
      } else {
        _pageController.animateToPage(
          targetWeek - 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _syncWeekScroll(targetWeek);
  }

  void _syncWeekScroll(int week) {
    if (!_weekScrollController.hasClients) return;
    final maxOffset = _weekScrollController.position.maxScrollExtent;
    final target = ((week - 1) * 48.0 - 96).clamp(0.0, maxOffset);
    if (MediaQuery.disableAnimationsOf(context)) {
      _weekScrollController.jumpTo(target);
    } else {
      _weekScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _syncPageWithScheduleContext(ScheduleProvider provider) {
    final start = provider.semesterStart;
    final signature =
        '${provider.activeSetId}|${start.year}-${start.month}-${start.day}';
    if (_scheduleContextSignature == signature) return;

    _scheduleContextSignature = signature;
    final targetWeek = provider.viewedWeek;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _scheduleContextSignature != signature) return;
      if (provider.viewedWeek != targetWeek) return;
      if (_pageController.hasClients &&
          _pageController.page?.round() != targetWeek - 1) {
        _pageController.jumpToPage(targetWeek - 1);
      }
      _syncWeekScroll(targetWeek);
    });
  }
}

class _ScheduleTitle extends StatelessWidget {
  const _ScheduleTitle({required this.provider, required this.subtitle});

  final ScheduleProvider provider;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final title = provider.activeSet?.name ?? '简课表';
    final titleContent = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (provider.scheduleSets.length > 1) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ],
      ),
    );

    if (provider.scheduleSets.length <= 1) return titleContent;

    return PopupMenuButton<String>(
      tooltip: '切换课表集',
      onSelected: (id) => provider.switchSet(id),
      itemBuilder: (context) => provider.scheduleSets.map((set) {
        final selected = set.id == provider.activeSetId;
        return PopupMenuItem(
          value: set.id,
          child: Row(
            children: [
              Icon(
                selected ? Icons.check : Icons.layers_outlined,
                size: 20,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  set.name,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Semantics(
        button: true,
        label: '当前课表集：$title，点击切换',
        child: titleContent,
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.viewedWeek,
    required this.actualTeachingWeek,
    required this.controller,
    required this.onSelected,
  });

  final int viewedWeek;
  final int? actualTeachingWeek;
  final ScrollController controller;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一周',
            onPressed: viewedWeek > 1 ? () => onSelected(viewedWeek - 1) : null,
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: maxWeekCount,
              itemBuilder: (context, index) {
                final week = index + 1;
                final selected = week == viewedWeek;
                final isActual = week == actualTeachingWeek;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '第$week周${isActual ? '，当前教学周' : ''}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    child: Material(
                      color: selected ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => onSelected(week),
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$week',
                                style: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected ? cs.onPrimary : cs.onSurface,
                                ),
                              ),
                              if (isActual && !selected)
                                Positioned(
                                  bottom: 4,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一周',
            onPressed: viewedWeek < maxWeekCount
                ? () => onSelected(viewedWeek + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

String _formatWeekRange(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return '${monday.month}月${monday.day}—${sunday.day}日';
  }
  return '${monday.month}月${monday.day}日—${sunday.month}月${sunday.day}日';
}
