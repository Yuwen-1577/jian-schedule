# Deep Static Code Review Report

This report presents the findings of a static code review of the Flutter application workspace targeting state management (R1), database operations (R2), and rendering/overlap resolution algorithms (R3).

---

## Executive Summary

The code review has identified several critical areas that can be optimized to improve system performance, UI responsiveness, and data integrity:
1. **R1 (State Management)**: Suboptimal build granularity due to broad `context.watch` calls on a global provider. Redundant notify calls occur during week transitions due to a missing guard in `setWeek`. High coupling with a concrete database implementation prevents mockability.
2. **R2 (Database Operations)**: A potential database connection race condition exists during parallel initialization. Foreign key constraints are declared in SQL but never enabled via SQLite pragma configurations. Critical multi-row modifications are performed without atomic transactions.
3. **R3 (Layout & Rendering)**: A layout bug in the column allocation algorithm causes non-overlapping courses to render as narrow cards if any other courses overlap during that day. Additionally, layout placement calculations are performed repeatedly during widget rebuilds.

---

## R1: State Management Design & Provider Usage

### 1. Broad UI Rebuild Scope (Lack of Granularity)
* **Location**: `lib/pages/schedule_page.dart:45` and `lib/widgets/week_grid.dart:20`
* **Observation**:
  In `SchedulePage`:
  ```dart
  45:     final provider = context.watch<ScheduleProvider>();
  ```
  In `WeekGrid`:
  ```dart
  20:     final provider = context.watch<ScheduleProvider>();
  ```
* **Analysis**:
  Using `context.watch<ScheduleProvider>()` binds the entire widget to all notifications from `ScheduleProvider`. 
  - For `SchedulePage`, changes in `ScheduleProvider` (such as adding, updating, or deleting a course, or editing a time slot) will trigger a rebuild of the entire main screen including the AppBar, the settings popup menus, and the week selection quick-scroller (`ListView.builder`).
  - For `WeekGrid` instances inside the `PageView`, they all listen to the entire provider. When a single course is edited on week 3, *every* instanced week grid (even those for other weeks currently cached in the PageView) will rebuild.
* **Refactoring Recommendation**:
  - In `SchedulePage`, replace `context.watch` with selective property watching using `context.select`:
    ```dart
    final currentWeek = context.select<ScheduleProvider, int>((p) => p.currentWeek);
    final scheduleSets = context.select<ScheduleProvider, List<ScheduleSet>>((p) => p.scheduleSets);
    final activeSetId = context.select<ScheduleProvider, String>((p) => p.activeSetId);
    final initialized = context.select<ScheduleProvider, bool>((p) => p.initialized);
    ```
  - In `WeekGrid`, instead of watching the entire provider, selectively watch only the time slots and the courses relevant to the week:
    ```dart
    final timeSlots = context.select<ScheduleProvider, List<TimeSlot>>((p) => p.timeSlots);
    final coursesForWeek = context.select<ScheduleProvider, List<Course>>(
      (p) => p.courses.where((c) => c.isActiveInWeek(week)).toList()
    );
    ```

### 2. Redundant Rebuilds from Unchecked Week Updates
* **Location**: `lib/providers/schedule_provider.dart:65-68`
* **Observation**:
  ```dart
  65:   void setWeek(int week) {
  66:     _currentWeek = week.clamp(1, maxWeekCount);
  67:     notifyListeners();
  68:   }
  ```
* **Analysis**:
  There is no guard clause to check if the new week is different from the current week. During PageView scrolls or programmatic week jumps (which trigger both `onPageChanged` and `animateToPage`), `setWeek` is called multiple times. Because `notifyListeners()` is executed unconditionally, it triggers cascading rebuilds across the entire widget tree for redundant values.
* **Refactoring Recommendation**:
  Add an equality check:
  ```dart
  void setWeek(int week) {
    final targetWeek = week.clamp(1, maxWeekCount);
    if (_currentWeek == targetWeek) return;
    _currentWeek = targetWeek;
    notifyListeners();
  }
  ```

### 3. Decoupling Between UI and Logic (Hardcoded Service Injection)
* **Location**: `lib/providers/schedule_provider.dart:13`
* **Observation**:
  ```dart
  13:   final DatabaseService _db = DatabaseService();
  ```
* **Analysis**:
  `ScheduleProvider` instantiates `DatabaseService` directly. This tight coupling makes it impossible to substitute a mock database service during unit testing.
* **Refactoring Recommendation**:
  Inject the dependency through the constructor:
  ```dart
  final DatabaseService _db;
  
  ScheduleProvider({DatabaseService? db}) : _db = db ?? DatabaseService();
  ```

---

## R2: Database Operations (sqflite) & Exception Boundaries

### 1. Concurrent Database Initialization Race Condition
* **Location**: `lib/services/database_service.dart:16-20`
* **Observation**:
  ```dart
  16:   Future<Database> get database async {
  17:     if (_database != null) return _database!;
  18:     _database = await _initDatabase();
  19:     return _database!;
  20:   }
  ```
* **Analysis**:
  If multiple database queries are issued concurrently at application startup (before `_database` is resolved), multiple callers will enter `_initDatabase()` simultaneously. This results in multiple parallel `openDatabase()` calls on the same SQLite file path, which can cause connection leaks, file locks, or database crashes.
* **Refactoring Recommendation**:
  Cache the initialization `Future` to ensure single-threaded execution:
  ```dart
  Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _dbFuture ??= _initDatabase();
    _database = await _dbFuture;
    return _database!;
  }
  ```

### 2. Inoperative Foreign Key Constraints
* **Location**: `lib/services/database_service.dart:25-30` (Missing `onConfigure` to execute Foreign Key Pragma)
* **Observation**:
  ```dart
  25:     return await openDatabase(
  26:       path,
  27:       version: 3,
  28:       onCreate: _onCreate,
  29:       onUpgrade: _onUpgrade,
  30:     );
  ```
* **Analysis**:
  Although the tables declare `FOREIGN KEY (scheduleSetId) REFERENCES schedule_sets(id) ON DELETE CASCADE` (line 58), SQLite disables foreign key constraint checks by default. Without executing `PRAGMA foreign_keys = ON`, the constraints are ignored. If a schedule set is deleted, SQLite will NOT automatically cascading-delete the associated courses.
* **Refactoring Recommendation**:
  Add an `onConfigure` block to enable foreign keys:
  ```dart
  return await openDatabase(
    path,
    version: 3,
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );
  ```

### 3. Non-Atomic Multi-Row Mutations (Missing Transactions)
* **Location**: `lib/services/database_service.dart:140-148`
* **Observation**:
  ```dart
  140:   Future<void> deleteScheduleSet(String id) async {
  141:     try {
  142:       final db = await database;
  143:       await db.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
  144:       await db.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
  145:     } on DatabaseException catch (e) {
  146:       throw Exception('删除课表集失败: $e');
  147:     }
  148:   }
  ```
* **Analysis**:
  This executes two separate delete statements without an surrounding transaction. If an error occurs on the second deletion or if the app crashes mid-execution, database integrity is broken: the courses will have been deleted but the schedule set will still exist.
* **Refactoring Recommendation**:
  Wrap the deletes in a database transaction:
  ```dart
  Future<void> deleteScheduleSet(String id) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('courses', where: 'scheduleSetId = ?', whereArgs: [id]);
        await txn.delete('schedule_sets', where: 'id = ?', whereArgs: [id]);
      });
    } on DatabaseException catch (e) {
      throw Exception('删除课表集失败: $e');
    }
  }
  ```
  *(Note: If foreign keys are enabled via `onConfigure`, the manual deletion of courses can be omitted, as SQLite's ON DELETE CASCADE will handle it automatically.)*

### 4. Missing Batching in JSON Import Loop
* **Location**: `lib/services/database_service.dart:318-322`
* **Observation**:
  ```dart
  318:         // 批量插入课程
  319:         for (final course in coursesList) {
  320:           await txn.insert('courses', course.toMap(),
  321:               conflictAlgorithm: ConflictAlgorithm.replace);
  322:         }
  ```
* **Analysis**:
  Calling `txn.insert` inside a loop executes separate SQL statements. While fast because it's inside a transaction, using a `Batch` object is the correct, performant, and standard approach to execute multiple operations in `sqflite`.
* **Refactoring Recommendation**:
  Refactor to use a Batch within the transaction:
  ```dart
  final batch = txn.batch();
  for (final course in coursesList) {
    batch.insert('courses', course.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
  ```

---

## R3: Column Allocation, Overlaps, and Rendering Performance

### 1. Global "totalCols" Overlap Algorithm Defect
* **Location**: `lib/widgets/week_grid.dart:330-355` (`calculatePlacements`) and lines `184-186`
* **Observation**:
  ```dart
  348:   final total = cols.length;
  349:   for (final e in cols.entries) {
  350:     for (final c in e.value) {
  351:       result.add(CoursePlacement(c, e.key, total));
  352:     }
  353:   }
  ```
  And then in rendering:
  ```dart
  185:         final left = (d - 1) * colWidth + p.colOffset * (colWidth / p.totalCols);
  186:         final width = colWidth / p.totalCols - 1;
  ```
* **Analysis**:
  The algorithm sets `totalCols` for *every* course in a day to the maximum number of overlapping columns *for the entire day* (`cols.length`).
  - **Scenario**: Suppose a day has two overlapping courses in Period 1-2 (requiring 2 columns) and a single, non-overlapping course in Period 5-6. 
  - **Result**: The course in Period 5-6 will be assigned `totalCols = 2`. The UI will render it with a width of `colWidth / 2` (50% of the day's width), leaving the other half empty even though there are no overlapping classes during Period 5-6. This is a layout defect.
* **Refactoring Recommendation**:
  Group courses into overlapping "clusters" (connected components). Within each cluster, assign local columns greedily. The width of each course should be based on the maximum number of columns *in its cluster*:
  ```dart
  List<CoursePlacement> calculatePlacements(List<Course> courses) {
    if (courses.isEmpty) return [];

    // Sort by start period and duration descending
    final sortedCourses = List<Course>.from(courses)
      ..sort((a, b) {
        final cmp = a.startPeriod.compareTo(b.startPeriod);
        if (cmp != 0) return cmp;
        return b.duration.compareTo(a.duration);
      });

    // Partition into overlapping clusters (connected components)
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

    // Greedy allocation per cluster
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

### 2. Repeated Algorithm Computation During Build
* **Location**: `lib/widgets/week_grid.dart:172-182`
* **Observation**:
  ```dart
  List<Widget> _buildCourseCards(BuildContext context, double colWidth) {
    // ...
    for (int d = 1; d <= days; d++) {
      final dayCourses = courseMap[d]!;
      final placements = calculatePlacements(dayCourses);
      // ...
  ```
* **Analysis**:
  `calculatePlacements` is called for every day (5 or 7 times) on *every rebuild* of `_GridBody`. When scrolling or swiping the PageView, this triggers redundant layout calculations, leading to GC pressure and potential frame drops (jank) on slower devices.
* **Refactoring Recommendation**:
  Since `WeekGrid` is currently a `StatelessWidget`, we can memoize the calculated placements in a stateful widget wrapper, or cache the layout placements inside the `ScheduleProvider` so they are computed only when the underlying courses change.

### 3. PageView Swiping Optimization
* **Location**: `lib/pages/schedule_page.dart:258-269`
* **Observation**:
  `PageView.builder` instantiates a `WeekGrid(week: index + 1)` on demand.
* **Analysis**:
  As the user swipes, offscreen grids are destroyed and recreated. While this is memory efficient, it re-runs all layout computations and widget creation upon swiping back.
* **Refactoring Recommendation**:
  Make `WeekGrid` keep its state alive by implementing a `StatefulWidget` with `AutomaticKeepAliveClientMixin`:
  ```dart
  class WeekGrid extends StatefulWidget {
    final int week;
    const WeekGrid({super.key, required this.week});

    @override
    State<WeekGrid> createState() => _WeekGridState();
  }

  class _WeekGridState extends State<WeekGrid> with AutomaticKeepAliveClientMixin {
    @override
    bool get wantKeepAlive => true;

    @override
    Widget build(BuildContext context) {
      super.build(context);
      // ... build logic ...
    }
  }
  ```
  This retains the calculated layouts and widgets for adjacent weeks, ensuring buttery-smooth swiping.

---

## Actionable Refactoring Summary

| Issue Reference | Impact | Refactoring Recommended |
|---|---|---|
| **R1.1: watch Scope** | High | Use `context.select` to limit rebuilds of `SchedulePage` and `WeekGrid` |
| **R1.2: setWeek Guard** | Medium | Add `if (_currentWeek == targetWeek) return;` to prevent redundant notifies |
| **R2.1: DB Init Race** | High | Use a cached Future `_dbFuture` to synchronize db connections |
| **R2.2: Foreign Keys** | Critical | Execute `PRAGMA foreign_keys = ON` in `onConfigure` to enforce ON DELETE CASCADE |
| **R2.3: DB Transactions** | High | Use `db.transaction()` for atomic multi-row updates in `deleteScheduleSet` |
| **R3.1: Layout Overlap** | High | Group courses into clusters before column assignment to avoid narrow cards |
| **R3.3: KeepAlive** | Medium | Implement `AutomaticKeepAliveClientMixin` on `WeekGrid` to optimize PageView swiping |
