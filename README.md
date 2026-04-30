# 简课表 (Simple Schedule)

跨平台课程表管理应用，支持 Android / iOS / Windows / Linux / macOS / Web。

## 功能

- 周视图课表，横向滑动切换 1-25 周
- 单双周自动过滤、今日周几高亮
- 添加/编辑/删除课程（名称、教室、教师、时间、颜色）
- 自定义上课时间表
- 今日课程侧边栏 + 当前节次进度指示
- 浅色/深色主题
- JSON 数据导出/导入备份
- 学期起始日设置（自动计算当前教学周）

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
│   ├── course.dart            # 课程模型（单双周、起止周、节次、颜色）
│   └── time_slot.dart         # 上课时间段模型
├── providers/
│   ├── schedule_provider.dart # 课表状态管理（CRUD、周次计算）
│   └── settings_provider.dart # 主题、显示设置
├── pages/
│   ├── schedule_page.dart     # 主页：PageView 横向滑动 + 侧边栏
│   ├── course_edit_page.dart  # 课程编辑表单
│   ├── time_setting_page.dart # 时间表配置
│   └── settings_page.dart     # 设置页（主题、导出/导入）
├── widgets/
│   ├── week_grid.dart         # 周课表网格（课程色块定位、重叠处理）
│   ├── course_card.dart       # 课程色块卡片
│   ├── time_column.dart       # 左侧时间列
│   ├── today_courses.dart     # 今日课程列表 + 当前节次进度
│   └── color_picker.dart      # 12 色预设选择器
├── services/
│   ├── database_service.dart  # sqflite CRUD（courses + time_slots 表）
│   └── export_service.dart    # JSON 导出/导入
└── utils/
    └── constants.dart         # 颜色预设、星期映射、周次计算
```

## 快速开始

### 环境要求

- Flutter SDK 3.41+
- Android SDK (build-tools 35+, platform 35+)
- JDK 17 (Android 构建)

### 构建 Android APK

```bash
flutter pub get
flutter build apk --release
```

APK 输出：`build/app/outputs/flutter-apk/app-release.apk`

### 安装到手机

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

或直接将 APK 传输到手机安装。

## 下载

从 [Releases](../../releases) 页面下载最新 APK。

## 开源协议

MIT License. 详见 [LICENSE](LICENSE) 文件。
