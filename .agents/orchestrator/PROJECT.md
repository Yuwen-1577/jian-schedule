# Project: class-schedule Code Review

## Architecture
- lib/providers/schedule_provider.dart: State management for schedules, calculations, etc.
- lib/services/database_service.dart: sqflite database CRUD operations.
- lib/widgets/week_grid.dart: Week grid rendering and overlap layout algorithm.
- lib/pages/schedule_page.dart: Home page showing schedules.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Explore | Deep static code review of R1, R2, R3 | none | DONE |
| 2 | Report Draft | Synthesize findings into code_review_report.md | M1 | DONE |
| 3 | Review & Audit | Verify correctness and integrity of report | M2 | DONE |

## Code Layout
- lib/
  - main.dart
  - models/
    - course.dart
    - schedule_set.dart
    - time_slot.dart
  - providers/
    - schedule_provider.dart
    - settings_provider.dart
  - pages/
    - schedule_page.dart
  - widgets/
    - week_grid.dart
  - services/
    - database_service.dart
