# 简课表 (Simple Schedule)

跨平台课程表管理应用。当前以 Android 为主要发布平台；iOS / Windows / Linux / macOS / Web 仍属实验性支持。

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

### 平台状态

| 平台 | 状态 |
|------|------|
| Android | 主要发布平台，已验证 Release 编译和 APK 打包 |
| iOS / macOS | 实验性，原生依赖与网络权限仍需完整验证 |
| Windows / Linux | 实验性，需按目标机器逐平台验证插件行为 |
| Web | 暂不建议发布，当前数据层和文件导入仍依赖 `dart:io` / SQLite |

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

> 正式发布构建必须使用与 `release.keystore` 匹配的本地签名配置。仅做本地 Release 模式冒烟验证时，可在 `android/` 目录执行 `gradlew assembleRelease -PuseDebugSigning=true`；该产物不可用于发布。

### 安装到手机

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

或直接将 APK 传输到手机安装。

## 下载

从 [Releases](../../releases) 页面下载最新 APK。

## 更新日志

### v2.5.1 (2026-07-13)

- **新增**：支持通过教务系统网页导入课表，并加入课程详情只读面板与 OCR 导入流程优化。
- **课表稳定性**：修正教学周边界、课表集切换、周视图与日视图同步，以及非连续周次解析问题。
- **导入可靠性**：Excel、OCR 与网页导入统一去重，准确反馈实际导入数量，并完善异常处理。
- **时间与提醒**：增加时间段合法性和重叠校验，修复后台同步竞态、通知时区和节次匹配问题。
- **Android 优化**：修复桌面小部件周次边界、课程结束状态与周视图色块重叠，并补齐联网权限。
- **质量保障**：补充核心逻辑测试；Android 已完成 release 模式构建验证，其他平台标记为实验性支持。

### v2.5.0 (2026-06-14)

- **核心升级**：智能 OCR 课表导入！支持通过截屏快速解析并导入复杂的二维课表网格，从此告别手动录入。
- **配置自由**：内置全流程大模型解析框架，支持自由填入兼容 OpenAI 格式的 API 接口（默认推荐阿里云通义千问模型）。
- **优化UI**：重构了课表集的展示与切换逻辑，将原本占据页面空间的切换按钮优化为 AppBar 下拉菜单，页面更清爽。
- **优化UI**：智能导入的课程现在会自动从预设调色盘中随机分配好看的马卡龙色，不再是清一色的绿色。
- **修复**：找回了在课程编辑面板中遗失的删除按钮。

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
