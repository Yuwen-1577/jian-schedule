# 简课表 Flutter 应用静态代码审查与重构建议报告

本报告针对简课表跨平台课表管理应用的 Dart 代码进行了深度的静态代码审查，并针对发现的问题提供了具体的重构与修复方案。审查重点涵盖状态管理（Provider 性能）、数据库操作（sqflite 数据完整性与并发性）以及界面网格定位布局算法。

---

## 1. SchedulePage 与 WeekGrid 状态监听重建范围过大

### 【发现的问题】
在 `SchedulePage` 和 `WeekGrid` 中，使用了 `context.watch<ScheduleProvider>()` 来绑定整个 `ScheduleProvider` 的状态。当 `ScheduleProvider` 中任何与这两个 Widget 无关的属性发生变化（例如添加、修改、删除课程，或者切换课表集等操作）时，都会导致这部分 Widget 及其子树被重新构建，状态监听的重建范围过大。

### 【具体的代码文件路径】
- `lib/pages/schedule_page.dart` (约第 45 行)
- `lib/widgets/week_grid.dart` (约第 20 行)

### 【潜在风险分析】
- **不必要的性能开销**：`SchedulePage` 是应用的核心骨架页面，包含 AppBar、侧边栏抽屉以及底部的周选择滑动条等。只要 `ScheduleProvider` 发送通知（例如后台自动刷新或与该周无关的课程修改），整个骨架树均会被强制重新构建，引发不必要的渲染和 GC 开销。
- **页面滑动卡顿**：`WeekGrid` 作为 PageView 中的子项，当滑动到其它周次或者当前周发生数据改变时，所有已缓存/实例化的周网格均会监听到整个 `ScheduleProvider` 的通知并全面重新构建。如果列表中包含多个周的数据，多次全树重建会导致滑动卡顿和页面卡死（Jank）。

### 【具体的重构/修复代码建议】

#### 针对 `lib/pages/schedule_page.dart` 的修改建议：

**修改前 (Before)：**
```dart
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final currentWeek = provider.currentWeek;

    // 使用今天的真实日期和星期
    final now = DateTime.now();
    String dateStr = '${now.year}.${now.month}.${now.day}';
    String weekDayStr = '周${weekdayShortNames[now.weekday - 1]}';
    String titleStr = '$dateStr 第$currentWeek周 $weekDayStr';

    if (!provider.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
```

**修改后 (After)：**
```dart
  @override
  Widget build(BuildContext context) {
    // 使用 context.select 仅监听当前 Page 真正依赖的特定字段，避免因其他字段变更触发重建
    final initialized = context.select<ScheduleProvider, bool>((p) => p.initialized);
    final currentWeek = context.select<ScheduleProvider, int>((p) => p.currentWeek);
    final scheduleSets = context.select<ScheduleProvider, List<ScheduleSet>>((p) => p.scheduleSets);
    final activeSetId = context.select<ScheduleProvider, String>((p) => p.activeSetId);
    
    // 对于不需要监听数据变化的调用方法操作，使用 context.read 获取 provider 的只读引用
    final provider = context.read<ScheduleProvider>();

    // 使用今天的真实日期和星期
    final now = DateTime.now();
    String dateStr = '${now.year}.${now.month}.${now.day}';
    String weekDayStr = '周${weekdayShortNames[now.weekday - 1]}';
    String titleStr = '$dateStr 第$currentWeek周 $weekDayStr';

    if (!initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
```

#### 针对 `lib/widgets/week_grid.dart` 的修改建议：

**修改前 (Before)：**
```dart
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final timeSlots = provider.timeSlots;
    final showWeekends = context.watch<SettingsProvider>().showWeekends;
    final days = showWeekends ? 7 : 5;

    if (timeSlots.isEmpty) {
      return const Center(child: Text('请先设置上课时间'));
    }
```

**修改后 (After)：**
```dart
  @override
  Widget build(BuildContext context) {
    // 仅监听时间段的更改，避免其它课程变动导致整个 Grid 顶部重建
    final timeSlots = context.select<ScheduleProvider, List<TimeSlot>>((p) => p.timeSlots);
    
    // 监听是否显示周末的设置
    final showWeekends = context.select<SettingsProvider, bool>((p) => p.showWeekends);
    final days = showWeekends ? 7 : 5;

    // 为了避免其它周的课程更改导致本周网格也重新构建，建议仅选择本周需要的课程列表
    final coursesForWeek = context.select<ScheduleProvider, List<Course>>(
      (p) => p.courses.where((c) => c.isActiveInWeek(week)).toList()
    );

    // 对于不需要监听数据变化的调用方法操作，使用 context.read 获取 provider 的只读引用
    final provider = context.read<ScheduleProvider>();

    if (timeSlots.isEmpty) {
      return const Center(child: Text('请先设置上课时间'));
    }
```

---

## 2. ScheduleProvider 中的 setWeek 缺少新旧值校验导致冗余通知

### 【发现的问题】
在 `ScheduleProvider` 的 `setWeek` 方法中，更改当前周时没有对新设置的周次 `week` 与原本的 `_currentWeek` 进行相等的判断校验。即使传入的周数与当前周数完全相同，该方法依然会调用 `notifyListeners()`，从而无条件地向所有订阅者发送通知。

### 【具体的代码文件路径】
- `lib/providers/schedule_provider.dart` (第 65-68 行)

### 【潜在风险分析】
- **冗余构建和性能损耗**：在 `SchedulePage` 进行滑动切换（如 PageView 滚动或快速跳转）时，`onPageChanged` 和 `animateToPage` 会频繁、多次调用 `setWeek` 方法。如果没有防抖/去重的校验，就会重复调用 `notifyListeners()`，在极短时间内强制整个 UI Widget 树进行多次无意义的重新构建，导致界面出现掉帧和滑动不跟手的现象。

### 【具体的重构/修复代码建议】

**修改前 (Before)：**
```dart
  // 切换周次
  void setWeek(int week) {
    _currentWeek = week.clamp(1, maxWeekCount);
    notifyListeners();
  }
```

**修改后 (After)：**
```dart
  // 切换周次
  void setWeek(int week) {
    final targetWeek = week.clamp(1, maxWeekCount);
    // 增加卫语句过滤相同值的修改，避免不必要的重新渲染
    if (_currentWeek == targetWeek) return;
    _currentWeek = targetWeek;
    notifyListeners();
  }
```

---

## 3. DatabaseService 中的数据库初始化并发连接竞态条件

### 【发现的问题】
`DatabaseService` 在初始化数据库连接时，`get database` 采用了非线性的检查方式。如果两个或更多的数据库查询请求在应用程序刚启动、`_database` 尚未加载完成时同时发起，它们会同时穿透 `if (_database != null)` 的判断，各自独立执行异步的 `_initDatabase()` 方法。

### 【具体的代码文件路径】
- `lib/services/database_service.dart` (第 16-20 行)

### 【潜在风险分析】
- **数据库连接泄露或文件锁异常**：并发调用 `openDatabase()` 去操作同一个 SQLite 物理数据库文件，可能导致底层产生多个数据库连接，也可能触发 SQLite 的文件独占锁报错（Database locked），导致部分操作失败，甚至在某些平台上直接引起应用崩溃。

### 【具体的重构/修复代码建议】

**修改前 (Before)：**
```dart
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
```

**修改后 (After)：**
```dart
  // 缓存初始化数据库的 Future 以防止并发竞争
  static Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // 如果已有初始化任务在进行，则等待相同的 Future 完成而不再重复调用 _initDatabase
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture;
    return _database!;
  }
```

---

## 4. SQLite 外键约束未生效导致级联删除失效

### 【发现的问题】
虽然 `courses` 表的创建 SQL 中定义了级联删除的外键约束 `FOREIGN KEY (scheduleSetId) REFERENCES schedule_sets(id) ON DELETE CASCADE`，但在使用 `openDatabase` 打开数据库时，未配置启用外键检查的 `onConfigure` 回调函数来执行 `PRAGMA foreign_keys = ON;` SQL 命令。

### 【具体的代码文件路径】
- `lib/services/database_service.dart` (第 25-30 行)

### 【潜在风险分析】
- **脏数据与孤儿记录**：SQLite 默认是关闭外键约束检测的。这意味着即使配置了 `ON DELETE CASCADE`，当父表记录（如某课表集 `schedule_sets`）被删除时，子表记录（如属于该课表集的课程 `courses`）**不会**自动执行关联级联删除。这会导致无用的脏数据长期残留于 `courses` 表中，造成数据不一致以及数据库空间无谓浪费。

### 【具体的重构/修复代码建议】

**修改前 (Before)：**
```dart
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'schedule.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
```

**修改后 (After)：**
```dart
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'schedule.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // 在配置阶段显式开启 SQLite 的外键级联检查支持
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }
```

---

## 5. DatabaseService 中的 deleteScheduleSet 存在非原子性的多行删除操作

### 【发现的问题】
在 `DatabaseService.deleteScheduleSet` 方法中，删除一个课表集时，会分别对 `courses` 表和 `schedule_sets` 表调用两次独立的 `delete` 操作。这两次操作属于不同的数据库连接交互过程，并且未被包裹在数据库事务中。

### 【具体的代码文件路径】
- `lib/services/database_service.dart` (第 140-148 行)

### 【潜在风险分析】
- **数据半截破坏（一致性破损）**：若在执行完第一句 `courses` 的删除后，由于系统异常、进程被强制杀死或发生底层的 SQLiteException，第二句 `schedule_sets` 没能顺利执行，最终会导致该课表集仍然残留在父表中，但其下属的所有课程已被全部清空。这破坏了数据操作的原子性（Atomicity）和一致性（Consistency）。

### 【具体的重构/修复代码建议】

**修改前 (Before)：**
```dart
  Future<void> deleteScheduleSet(String id) async {
    try {
      final db = await database;
      await db.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
      await db.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      throw Exception('删除课表集失败: $e');
    }
  }
```

**修改后 (After)：**
```dart
  Future<void> deleteScheduleSet(String id) async {
    try {
      final db = await database;
      // 将多个修改语句整合到单个原子事务中，确保要么全部成功要么全部回滚
      await db.transaction((txn) async {
        await txn.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
        await txn.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
      });
    } on DatabaseException catch (e) {
      throw Exception('删除课表集失败: $e');
    }
  }
```

---

## 6. week_grid.dart 中的全局 totalCols 重叠分配算法缺陷导致非重叠课程卡片被无故缩窄

### 【发现的问题】
在 `week_grid.dart` 的 `calculatePlacements` 中，处理一天的课程重叠计算时，会将这一天内所有放置到临时列映射 `cols` 中的课程，强制将其 `totalCols` 设置为当天的全局最大总列数（`cols.length`）。
此外，该计算会导致与任何课程都无重叠的其他节次课程也使用该全局最大列数，导致渲染出来的卡片异常缩窄。
同时，单双周混合测试用例中在 `test/widget_test.dart` 第 331 行 `expect(cPlacement.totalCols, 2);` 固化了这一错误预期。

### 【具体的代码文件路径】
- 算法定义文件：`lib/widgets/week_grid.dart` (第 330-355 行)
- 测试定义文件：`test/widget_test.dart` (第 322-333 行)

### 【潜在风险分析】
- **布局渲染错误**：当一天的早上第 1-2 节有重叠的两门课（分配到 2 列，`cols.length` 达到 2），而下午第 5-6 节只有一门课（完全不重叠）时。下午的那门课的 `totalCols` 也会被设置成 2，它的排版宽度将只占该天总宽度的 50%，右侧留下巨大的一片无用留白。
- **用户体验差**：在周课表界面，学生会发现没有冲突的课程卡片也变得非常细窄，字体重叠不可读，影响界面美观及使用。

### 【具体的重构/修复代码建议】

#### 针对 `lib/widgets/week_grid.dart` 的修改建议：

**修改前 (Before)：**
```dart
@visibleForTesting
List<CoursePlacement> calculatePlacements(List<Course> courses) {
  if (courses.isEmpty) return [];
  final cols = <int, List<Course>>{};

  for (final c in courses) {
    int col = 0;
    while (true) {
      cols.putIfAbsent(col, () => []);
      final hasOverlap = cols[col]!.any((e) => overlaps(c, e));
      if (!hasOverlap) {
        cols[col]!.add(c);
        break;
      }
      col++;
    }
  }

  final result = <CoursePlacement>[];
  final total = cols.length;
  for (final e in cols.entries) {
    for (final c in e.value) {
      result.add(CoursePlacement(c, e.key, total));
    }
  }
  return result;
}
```

**修改后 (After)：**
```dart
@visibleForTesting
List<CoursePlacement> calculatePlacements(List<Course> courses) {
  if (courses.isEmpty) return [];

  // 1. 按照上课节次由早到晚，时长由长到短进行排序
  final sortedCourses = List<Course>.from(courses)
    ..sort((a, b) {
      final cmp = a.startPeriod.compareTo(b.startPeriod);
      if (cmp != 0) return cmp;
      return b.duration.compareTo(a.duration);
    });

  // 2. 将互相重叠的课程划分为不同的“重叠簇 (Clusters)”（连通分量）
  final clusters = <List<Course>>[];
  for (final c in sortedCourses) {
    List<Course>? targetCluster;
    for (final cluster in clusters) {
      if (cluster.any((e) => overlaps(c, e))) {
        targetCluster = cluster;
        break;
      }
    }
    if (targetCluster != null) {
      targetCluster.add(c);
    } else {
      clusters.add([c]);
    }
  }

  final placements = <CoursePlacement>[];

  // 3. 针对每个重叠簇独立进行贪婪列分配
  for (final cluster in clusters) {
    final cols = <int, List<Course>>{};
    for (final c in cluster) {
      int col = 0;
      while (true) {
        cols.putIfAbsent(col, () => []);
        final hasOverlap = cols[col]!.any((e) => overlaps(c, e));
        if (!hasOverlap) {
          cols[col]!.add(c);
          break;
        }
        col++;
      }
    }

    // 该簇所占用的最大列数就是此簇内课程的 totalCols，而非整个大列表的全局总列数
    final clusterTotalCols = cols.length;
    for (final entry in cols.entries) {
      for (final c in entry.value) {
        placements.add(CoursePlacement(c, entry.key, clusterTotalCols));
      }
    }
  }

  return placements;
}
```

#### 针对 `test/widget_test.dart` 中相关测试的修改建议：

**修改前 (Before)：**
```dart
    test('calculatePlacements handles three mixed courses', () {
      final courses = [
        makeCourse('a', 1, 2),
        makeCourse('b', 2, 2),
        makeCourse('c', 5, 2),
      ];
      final placements = calculatePlacements(courses);
      expect(placements.length, 3);
      final cPlacement = placements.firstWhere((p) => p.course.id == 'c');
      expect(cPlacement.totalCols, 2);
      expect(cPlacement.colOffset, 0);
    });
```

**修改后 (After)：**
```dart
    test('calculatePlacements handles three mixed courses', () {
      final courses = [
        makeCourse('a', 1, 2),
        makeCourse('b', 2, 2),
        makeCourse('c', 5, 2),
      ];
      final placements = calculatePlacements(courses);
      expect(placements.length, 3);
      final cPlacement = placements.firstWhere((p) => p.course.id == 'c');
      // 经过重组簇划分算法修复后，没有与 a、b 重叠的下午课程 c 应正确独占 1 列，不应被缩窄为 2
      expect(cPlacement.totalCols, 1);
      expect(cPlacement.colOffset, 0);
    });
```
