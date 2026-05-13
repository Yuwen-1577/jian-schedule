# CLAUDE.md

## 仓库信息
- GitHub: https://github.com/Yuwen-1577/jian-schedule (公开)
- 用户 GitHub: Yuwen-1577
- 本文件在 .gitignore 中，不在远程仓库

## 项目概要
简课表 Flutter 跨平台实现。Android/iOS/Windows/Linux/macOS/Web 全平台课表管理应用。

## 技术栈
- Flutter 3.41+ / Dart 3.1+
- Provider 状态管理
- sqflite 本地数据库
- shared_preferences 配置存储

## 项目结构
```
lib/
├── main.dart                  # 入口，MultiProvider 配置
├── models/
│   ├── course.dart            # 课程模型（单双周、起止周、节次、颜色、所属课表集）
│   ├── schedule_set.dart      # 课表集模型（名称、学期开始日期）
│   └── time_slot.dart         # 上课时间段模型
├── providers/
│   ├── schedule_provider.dart # 课表状态管理（CRUD、周次计算、多课表集切换）
│   └── settings_provider.dart # 主题、显示设置
├── pages/
│   ├── schedule_page.dart           # 主页：PageView 横向滑动 + 侧边栏 + 课表集切换
│   ├── course_edit_page.dart        # 课程编辑表单
│   ├── time_setting_page.dart       # 时间表配置
│   ├── settings_page.dart           # 设置页（主题、导出/导入、Excel导入）
│   ├── schedule_set_manage_page.dart # 课表集管理（创建/重命名/删除）
│   └── about_page.dart              # 关于页面（版本、平台、技术栈）
├── widgets/
│   ├── week_grid.dart         # 周课表网格（课程色块定位、重叠处理）
│   ├── course_card.dart       # 课程色块卡片
│   ├── time_column.dart       # 左侧时间列
│   ├── today_courses.dart     # 今日课程列表 + 当前节次进度
│   └── color_picker.dart      # 12 色预设选择器
├── services/
│   ├── database_service.dart  # sqflite CRUD（schedule_sets + courses + time_slots 表）
│   ├── export_service.dart    # JSON 导出/导入
│   └── xls_import_service.dart # Excel (.xlsx) 课表解析导入
└── utils/
    └── constants.dart         # 颜色预设、星期映射、周次计算
```

## 数据模型
- **ScheduleSet**: id, name, semesterStart, sortOrder
- **Course**: id, name, room, teacher, day(1-7), startPeriod, duration, startWeek, endWeek, weekType(0全周/1单周/2双周), colorValue, note, scheduleSetId
- **TimeSlot**: period, startTime("HH:mm"), endTime("HH:mm")

## 关键设计决策
- 课表用 PageView 而非 TabBar（模仿 WakeUp 横向滑动切周）
- 课程重叠通过列分配算法处理（同时间段多课程并排显示）
- 学期开始日期 → 自动计算当前教学周
- 主题切换通过 SettingsProvider → MaterialApp.themeMode
- 多课表集：AppBar 弹出菜单切换，每个课表集独立课程和学期日期
- 导出格式为自定义 JSON v2.0（含 scheduleSets + courses + timeSlots）
- Excel 导入仅支持 .xlsx（.xls 需先另存为 .xlsx）

## 构建命令
```bash
# 依赖
flutter pub get

# 构建 APK
export JAVA_HOME="/c/Program Files/Amazon Corretto/jdk17.0.19_10"
export ANDROID_HOME="$HOME/AppData/Local/Android/Sdk"
flutter build apk --release
```
APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

## 包名
`com.suda.yzune.class_schedule`

## 注意事项
- 需要 Windows 开发者模式（插件 symlink）
- 需要 JDK 17（AGP 8+ 要求）
- 需要 Android SDK build-tools 35+, platform 35+
