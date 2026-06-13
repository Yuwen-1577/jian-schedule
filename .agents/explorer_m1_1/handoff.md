# Handoff Report: Static Code Review findings (M1)

## 1. Observation

During the static code review, the following exact code locations and patterns were observed:

### R1: State Management & Decoupling
- **Broad Rebuild Triggers**:
  - `lib/pages/schedule_page.dart:45`: `final provider = context.watch<ScheduleProvider>();` binds the entire main view to every provider update.
  - `lib/widgets/week_grid.dart:20`: `final provider = context.watch<ScheduleProvider>();` causes every cached week grid in the pageview to rebuild on any provider modification.
- **Unconditional Week Notifications**:
  - `lib/providers/schedule_provider.dart:65-68`:
    ```dart
    void setWeek(int week) {
      _currentWeek = week.clamp(1, maxWeekCount);
      notifyListeners();
    }
    ```
    This lack of equality check leads to redundant notifications during PageView swipes.
- **Concrete Dependency**:
  - `lib/providers/schedule_provider.dart:13`: `final DatabaseService _db = DatabaseService();` locks the provider to the concrete DB singleton.

### R2: SQLite Operations (sqflite)
- **Concurrent DB Opens**:
  - `lib/services/database_service.dart:16-20`:
    ```dart
    Future<Database> get database async {
      if (_database != null) return _database!;
      _database = await _initDatabase();
      return _database!;
    }
    ```
    If accessed concurrently during startup, `_initDatabase()` will execute multiple times.
- **Disabled Foreign Key Constraints**:
  - `lib/services/database_service.dart:25-30`: `openDatabase(...)` is executed without a custom `onConfigure` calling `PRAGMA foreign_keys = ON;`.
- **Non-Atomic Operations**:
  - `lib/services/database_service.dart:140-148`: `deleteScheduleSet` executes two separate delete statements without an outer transaction.
- **Insert Loop in Transactions**:
  - `lib/services/database_service.dart:318-322`: Inside a transaction, `txn.insert` is called inside a standard loop without utilizing `txn.batch()`.

### R3: Column Allocation & Overlap Resolution
- **Day-Wide Column Scale**:
  - `lib/widgets/week_grid.dart:348`: `final total = cols.length;` assigns the day-wide total column count to all courses, including those that do not overlap with anything.
- **Test Invariant of the Bug**:
  - `test/widget_test.dart:322-334` contains the following test:
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
    This explicitly asserts that a non-overlapping course `c` (Period 5-6) gets restricted to `totalCols = 2` because course `a` and `b` (Period 1-3) overlap. This asserts and locks in the buggy behavior.

---

## 2. Logic Chain

1. **State Over-Notification**: Since `setWeek` does not check if the value is unchanged, swipes/animations call `setWeek` multiple times with the same week, resulting in multiple calls to `notifyListeners()`. Because `SchedulePage` and all `WeekGrid`s watch the provider broadly via `context.watch`, this causes multiple expensive widget tree layout passes and rendering operations during swiping, inducing UI jank.
2. **Data Integrity Hazards**: SQLite disables foreign key checks by default. Since `PRAGMA foreign_keys = ON` is omitted, `ON DELETE CASCADE` is inactive. Although `deleteScheduleSet` deletes courses manually, any other entry points or external scripts will bypass this, leading to database fragmentation and orphaned course rows.
3. **Connection Leaks**: `get database` resolves the database field via `_database = await _initDatabase()`. Concurrent calls before the field is assigned will cause multiple parallel database openings, which violates sqflite singleton safety.
4. **Layout/Rendering Defect**: Because `totalCols` represents the *total* number of columns used anywhere in the day, a single-instance course in a slot with no overlap gets rendered with a width fraction corresponding to other unrelated overlaps. This shrinks non-overlapping classes and leaves wide blank columns in the daily grid.

---

## 3. Caveats

- Did not test performance on low-end physical Android/iOS devices; assessment of jank is based on CPU layout recalculation profiling and static inspection of build paths.
- Did not review the binary excel parsing service (`xls_import_service.dart`) or desktop widget services (`widget_service.dart`), as they were outside of the targeted review scope.

---

## 4. Conclusion

The codebase is highly functional but suffers from standard performance and safety patterns that need refactoring:
- Implement `context.select` and week-guard checks to prevent redundant rebuilds.
- Enable SQL foreign key pragmas, synchronize connection initialization, and wrap bulk mutations in transaction batches.
- Correct the layout overlap logic in `week_grid.dart` by grouping courses into clusters prior to column assignment.
- Update the unit test in `test/widget_test.dart` to expect `totalCols = 1` for course `c` in the mixed-courses test.

---

## 5. Verification Method

### 1. Verification of Layout Bug and fix
- Run: `flutter test`
- Inspect `test/widget_test.dart` (lines 322-334). The test will FAIL if the layout bug is fixed because the new cluster-based algorithm correctly assigns `totalCols = 1` to course `c`.
- **Correction Criterion**: Modify `expect(cPlacement.totalCols, 2);` to `expect(cPlacement.totalCols, 1);` in `test/widget_test.dart` to match correct layout behavior, and confirm `flutter test` passes successfully.

### 2. Verify Rebuilds
- Add a print log statement inside `SchedulePage.build` and `WeekGrid.build`.
- Run the application, swipe between weeks, and notice that the build logs print repeatedly for the same week.
- Apply the equality guard to `setWeek` and notice that the redundant builds drop to zero.
