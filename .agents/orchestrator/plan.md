# Code Review Plan

## Objective
Coordinate a deep code review of the class-schedule Flutter codebase, focusing on R1 (State Management), R2 (Database/Async), and R3 (Core Algorithm & UI/UX), producing a high-quality `code_review_report.md` in the workspace.

## Steps
1. **Initialize**: Set up configuration and workflow (Done).
2. **Investigation (Explorer)**:
   - Spawn `teamwork_preview_explorer` to analyze:
     - `lib/providers/schedule_provider.dart` (state management, rebuild efficiency)
     - `lib/services/database_service.dart` (sqflite usage, transaction, errors)
     - `lib/widgets/week_grid.dart` (overlap resolution algorithm complexity/rendering)
     - `lib/pages/schedule_page.dart` (pageview optimization, potential memory leaks)
   - Wait for explorer's analysis and report.
3. **Drafting (Worker)**:
   - Spawn `teamwork_preview_worker` to compile the findings and construct `code_review_report.md`.
   - The worker must address at least 3 technical debts/bugs and propose at least 1 refactoring suggestion with code snippets.
4. **Review & Audit**:
   - Spawn `teamwork_preview_reviewer` to review `code_review_report.md`.
   - Spawn `teamwork_preview_auditor` to audit integrity (no cheating, no hardcoded verification).
5. **Finalization**:
   - Deliver the final report to the Sentinel.
