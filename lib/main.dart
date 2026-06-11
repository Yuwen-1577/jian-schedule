import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/schedule_provider.dart';
import 'providers/settings_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'utils/constants.dart';
import 'pages/schedule_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注册桌面小部件背景回调
  HomeWidget.registerInteractivityCallback(backgroundCallback);

  // 初始化通知服务
  await NotificationService().initialize();

  final settings = SettingsProvider();
  await settings.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScheduleProvider()..loadData()),
        ChangeNotifierProvider.value(value: settings),
      ],
      child: const ScheduleApp(),
    ),
  );
}

/// 桌面小部件背景回调
/// 由 WorkManager 触发，运行在独立 isolate 中
/// 重新初始化数据库并同步最新数据到 Widget
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 在独立 isolate 中需要重新初始化数据库连接
    final db = DatabaseService();

    // 读取当前活跃课表集 ID（由 ScheduleProvider 同步写入）
    final prefs = await SharedPreferences.getInstance();
    final activeSetId = prefs.getString('activeSetId') ?? defaultSetId;

    final courses = await db.getCoursesBySet(activeSetId);
    final timeSlots = await db.getTimeSlots();
    final scheduleSets = await db.getScheduleSets();

    if (scheduleSets.isEmpty) return;

    // 找到当前活跃集的学期开始日期
    final activeSet = scheduleSets.firstWhere(
      (s) => s.id == activeSetId,
      orElse: () => scheduleSets.first,
    );
    final today = DateTime.now().weekday;
    final currentWeek = calculateCurrentWeek(activeSet.semesterStart);

    // 过滤今日课程
    final todayCourses = courses.where((c) {
      if (c.day != today) return false;
      if (!c.isActiveInWeek(currentWeek)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

    // 同步三种 Widget
    await WidgetService.syncTodayCourses(todayCourses, timeSlots);
    await WidgetService.syncWeekGrid(courses, currentWeek);
    await WidgetService.updateAll();
  } catch (e) {
    // 背景回调错误不影响主功能，仅记录日志
    debugPrint('backgroundCallback error: $e');
  }
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: '简课表',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.seedColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.seedColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
          ),
          home: const SchedulePage(),
        );
      },
    );
  }
}
