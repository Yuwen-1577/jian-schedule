# 简课表 (Simple Schedule)

跨平台课程表管理应用，支持 Android / iOS / Windows / Linux / macOS / Web。

## 功能

- 周视图课表，横向滑动切换 1-25 周
- 单双周自动过滤、今日周几高亮
- 添加/编辑/删除课程（名称、教室、教师、时间、颜色、提醒）
- 多课表集管理（创建/切换/重命名/删除）
- Excel (.xlsx) 课表文件导入（智能表头检测、合并单元格、单双周识别）
- 自定义上课时间表
- 今日课程侧边栏 + 当前节次进度指示
- 课程提醒通知（5 分钟 / 10 分钟 / 15 分钟 / 30 分钟 / 1 小时）
- Material 3 主题 + 10 种预设主题色 + 自定义颜色
- 浅色 / 深色 / 跟随系统主题
- JSON 数据导出/导入备份
- 学期起始日设置（自动计算当前教学周）
- Android 桌面小部件（今日课程 / 课程列表 / 周课表网格）

## 技术栈

- Flutter 3.41+ / Dart 3.1+
- Provider 状态管理
- sqflite 本地数据库
- shared_preferences 配置存储
- flutter_local_notifications 课程提醒
- home_widget 桌面小部件

## 项目结构

```
lib/
├── main.dart                  # 入口，MultiProvider 配置
├── models/
│   ├── course.dart            # 课程模型（单双周、起止周、节次、颜色、提醒）
│   ├── schedule_set.dart      # 课表集模型（名称、学期开始日期）
│   └── time_slot.dart         # 上课时间段模型
├── providers/
│   ├── schedule_provider.dart # 课表状态管理（CRUD、周次计算、多课表集切换）
│   └── settings_provider.dart # 主题、显示设置
├── pages/
│   ├── schedule_page.dart           # 主页：PageView 横向滑动 + 侧边栏 + 课表集切换
│   ├── course_edit_page.dart        # 课程编辑表单（含提醒时间选择）
│   ├── time_setting_page.dart       # 时间表配置
│   ├── settings_page.dart           # 设置页（主题、导出/导入、Excel导入、通知）
│   ├── schedule_set_manage_page.dart # 课表集管理（创建/重命名/删除）
│   └── about_page.dart              # 关于页面（版本、平台、技术栈）
├── widgets/
│   ├── week_grid.dart         # 周课表网格（课程色块定位、重叠处理）
│   ├── course_card.dart       # 课程色块卡片
│   ├── time_column.dart       # 左侧时间列
│   ├── today_courses.dart     # 今日课程列表 + 当前节次进度
│   └── color_picker.dart      # 12 色预设选择器
├── services/
│   ├── database_service.dart  # sqflite CRUD + JSON 导出/导入
│   ├── notification_service.dart # 课程提醒通知调度
│   ├── widget_service.dart    # 桌面小部件数据同步
│   └── xls_import_service.dart # Excel (.xlsx) 课表解析导入
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

## 更新日志

### v2.4.0 (2026-06-14)

- 新增：日视图 — 纵向时间轴展示每日课程，精确显示课程时间和间隔
- 新增：底部导航栏（周视图 / 日视图 / 设置），支持 Tab 快速切换
- 新增：日视图当前时间红线实时指示
- 新增：日视图水平日期选择条，支持左右滑动切换周

### v2.3.0 (2026-06-13)

- 重构：课程周次由“单双周/起止周”模式彻底升级为“任意多选周”模式，支持任意跳跃周次的复杂排课
- 数据库：升级至 V4，新增 `activeWeeks` 字段支持数组存储
- 修复：修复打包时 Gradle 内存限制过高导致偶尔崩溃闪退的问题

### v2.2.0 (2026-06-13)

- 优化UI：引入并支持全局自定义中文字体（如高颜值衬线体），提供原生的书卷气息排版
- 优化UI：调整课程卡片莫兰迪底色对比度，解决深色模式卡片过暗以及文字辨识度低的问题
- 优化UI：增加堆叠课程卡片的重叠层数角标，并将其移至卡片右下角以防止遮挡课程名称
- 修复：修复深色模式堆叠卡片时由于颜色相近导致显示重叠错位或融合的问题

### v2.1.0 (2026-06-12)

- 全新设计系统：暖灰中性色、Claude 风格极简视觉、统一间距/圆角/字体 token
- 课程卡片重做：低饱和度背景 + 左侧色条，去掉 BoxShadow
- 主题切换改为 SegmentedButton（浅色/深色/跟随系统）
- 课表网格、时间列、今日课程全部迁移到 colorScheme token
- 修复桌面小部件：学期开始日期同步、周次计算 off-by-one、周视图只显示今天课程
- 修复 Excel 导入：duration 不再硬编码为 2、`[01-02节]` 不再腐蚀周次解析、非连续奇偶周正确识别 weekType

### v2.0.1 (2026-06-12)

- 修复 Android 13+ 通知权限缺失导致提醒静默失败
- 修复开机后通知丢失（新增 BootReceiver 自动重调度）
- 修复暗色模式下课表头部背景、抽屉边框、颜色选择器边框不可见
- 迁移 `Color.value` 废弃 API 至 `toARGB32()`
- 启动时显示加载指示器，Excel 导入新增冲突警告
- 提取公共 `stableId()` 函数，消除重复代码
- 新增 28 个单元测试（总计 39 个），覆盖核心业务逻辑

### v2.0.0 (2026-06-12)

- 新增课程提醒通知，支持 5 分钟~1 小时提前提醒，每门课程独立设置
- 新增 Material 3 种子色主题系统，10 种预设 + 自定义调色盘
- Excel 导入增强：智能表头检测、合并单元格处理、单双周自动分析
- 桌面小部件 Kotlin 端重构，稳定性提升
- 版本号改为动态读取，消除硬编码
- 修复通知 ID 跨平台一致性问题
- 修复 Excel 导入课程 ID 为空导致的数据冲突

### v1.3.1 (2026-05-13)

- 修复桌面小部件数据同步问题

### v1.3.0 (2026-05-13)

- 新增 Android 桌面小部件（今日课程 / 课程列表 / 周课表网格）

### v1.2.0 (2026-05-02)

- 新增 Excel (.xlsx) 课表导入
- 新增多课表集管理

### v1.1.0 (2026-05-01)

- 课程卡片点击进入编辑页
- 修复设置页版本号显示

### v1.0.0 (2026-04-30)

- 首次发布：周课表、课程 CRUD、深色主题、JSON 备份

## 开源协议

MIT License. 详见 [LICENSE](LICENSE) 文件。
