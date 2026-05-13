import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:home_widget/home_widget.dart';
import 'providers/schedule_provider.dart';
import 'providers/settings_provider.dart';
import 'services/database_service.dart';
import 'services/widget_service.dart';
import 'pages/schedule_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注册桌面小部件背景回调
  HomeWidget.registerInteractivityCallback(backgroundCallback);

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
  
  // 在独立 isolate 中需要重新初始化数据库连接
  final db = DatabaseService();
  final courses = await db.getCoursesBySet('default');
  final timeSlots = await db.getTimeSlots();
  final scheduleSets = await db.getScheduleSets();

  if (scheduleSets.isEmpty) return;

  final activeSet = scheduleSets.first;
  final today = DateTime.now().weekday;
  final semesterStart = activeSet.semesterStart;
  final diff = DateTime.now().difference(semesterStart).inDays;
  final currentWeek = ((diff / 7).ceil()).clamp(1, 25);

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
              seedColor: Colors.blue,
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
              seedColor: Colors.blue,
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
