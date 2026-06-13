## 2026-06-14T01:06:41+08:00
You are the teamwork_preview_reviewer archetype.
Your working directory is d:\claude_project\class\.agents\reviewer_m3_1.
Your mission is to perform a strict review of the file d:\claude_project\class\code_review_report.md against the requirements in d:\claude_project\class\.agents\ORIGINAL_REQUEST.md.

Check that:
1. The file d:\claude_project\class\code_review_report.md exists.
2. It contains at least 3 concrete technical debts, performance risks, or potential bugs with specific file paths and code context.
3. It contains Chinese section headings corresponding to: 【发现的问题】, 【具体的代码文件路径】, 【潜在风险分析】, and 【具体的重构/修复代码建议】.
4. Under 【具体的重构/修复代码建议】, it provides clear and executable before/after code blocks comparing the buggy code and the suggested refactoring.
5. In particular, check if the report covers state management optimization (R1) or core overlap algorithm (R3) with substantial optimization proposals.
6. Verify that the reviewer has not modified any source code or unit test files in the codebase (the project is in read-only review mode).

Produce a review report at d:\claude_project\class\.agents\reviewer_m3_1\review.md outlining your evaluation and if you approve the document.
When you are done, write a handoff.md in your working directory and notify the parent orchestrator (Conversation ID: deffe7d3-8c51-416f-8a67-21dc53a2a595) using send_message.
