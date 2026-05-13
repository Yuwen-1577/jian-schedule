# 架构文档

## 数据流

```
用户操作 → Provider.notifyListeners() → Consumer/context.watch 重建 UI
                ↕
         DatabaseService (sqflite)
```

## 数据模型

### ScheduleSet（课表集）
```
id: UUID字符串
name: 课表集名称
semesterStart: 学期开始日期 (ISO 8601)
sortOrder: 排序序号
```

### Course（课程）
```
id: UUID字符串
name: 课程名
room: 教室
teacher: 教师
day: 1-7 (周一至周日)
startPeriod: 开始节次 (1-based)
duration: 持续节数
startWeek: 起始周
endWeek: 结束周
weekType: 0全周 / 1单周 / 2双周
colorValue: ARGB 颜色值
note: 备注
scheduleSetId: 所属课表集 ID
```

### TimeSlot（时间段）
```
period: 节次编号 (1-based)
startTime: "HH:mm" 字符串
endTime: "HH:mm" 字符串
```

## 状态管理

**ScheduleProvider** — 课程和时间表的单一数据源：
- `courses` — 当前活动课表集的课程列表
- `timeSlots` — 所有时间段
- `currentWeek` — 当前教学周（根据学期起始日自动计算）
- `scheduleSets` — 所有课表集列表
- `activeSetId` — 当前活动课表集 ID
- `getCoursesForDay(week, day)` — 按周+日过滤课程（含单双周判断）
- `switchSet(setId)` — 切换活动课表集
- `createSet(name)` / `renameSet(id, name)` / `deleteSet(id)` — 课表集管理

**SettingsProvider** — 应用设置：
- `themeMode` — light/dark/system
- `showWeekends` — 是否显示周六日

## 课表布局算法

周课表网格采用绝对定位：
1. 左侧 TimeColumn（固定48px宽，显示每节课起止时间）
2. 右侧 Stack + Positioned 放置课程卡片
3. 列分配算法处理课程时间重叠：同一日多个课程按列并排

```
[时间列] [周一] [周二] [周三] [周四] [周五]
 08:00  ┌──────┐
 08:45  │ 高数  │
 08:55  │ 3-101 │
 09:40  └──────┘
 10:00     ┌──────┐
 10:45     │ 英语  │
 10:55     │ 2-205 │
 11:40     └──────┘
```

## 数据库

SQLite (`schedule.db`)，三张表：

```sql
schedule_sets (id TEXT PK, name TEXT, semesterStart TEXT, sortOrder INT)

courses (id TEXT PK, name TEXT, room TEXT, teacher TEXT, day INT, 
         startPeriod INT, duration INT, startWeek INT, endWeek INT,
         weekType INT, colorValue INT, note TEXT, scheduleSetId TEXT)

time_slots (period INT PK, startTime TEXT, endTime TEXT)
```

## 导出/导入

JSON 格式（v2.0）：
```json
{
  "version": "2.0",
  "exportDate": "<ISO 8601 timestamp>",
  "scheduleSets": [...],
  "courses": [...],
  "timeSlots": [...]
}
```

兼容 v1.0 格式（无 scheduleSets 字段），导入时自动创建默认课表集。

Excel 导入：支持 .xlsx 格式教务系统课表文件，通过 `XlsImportService` 解析。
