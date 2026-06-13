# Original User Request

## 2026-06-14T01:01:16Z

对简课表（Flutter 跨平台应用）项目进行深度代码审查，重点评估 Provider 状态管理、数据库性能、核心算法及 UI 渲染，最终交付一份结构化的 Markdown 审查报告。

Working directory: d:\claude_project\class
Integrity mode: development

## Requirements

### R1. 架构设计与状态管理审查
- 深入分析 `lib/providers/`（如 `schedule_provider.dart`）的状态管理实现。
- 检查是否存在状态滥用、不必要的 UI 重绘（例如评估 `Consumer` 和 `context.watch/select` 的颗粒度是否合理）。
- 评估业务逻辑是否与 UI 视图层实现了良好的解耦。

### R2. 本地数据库与异步操作审查
- 重点评估 `lib/services/database_service.dart` 中的 sqflite 数据库操作逻辑。
- 检查表设计、并发查询性能、事务（Transactions）的使用，以及异步操作的错误处理与异常边界情况。

### R3. 核心算法与 UI/UX 性能评估
- 针对 `lib/widgets/week_grid.dart` 中的课程重叠处理及列分配算法，评估其时间复杂度和渲染稳定性。
- 检查主页 `schedule_page.dart`（基于 PageView）及其他核心页面的组件封装质量，排查潜在的内存泄漏或性能瓶颈。

### R4. 审查报告生成
在工作区内生成名为 `code_review_report.md` 的审查报告，结构需包含：【发现的问题】、【具体的代码文件路径】、【潜在风险分析】以及【具体的重构/修复代码建议】。

## Acceptance Criteria

### 报告质量与客观性要求
- [ ] 必须在工作区生成 `code_review_report.md`。
- [ ] 报告中必须明确指出至少 3 个具体的技术债务、性能隐患或潜在 Bug（例如：过度的组件重绘、数据库读写风险、算法缺陷等）。
- [ ] 针对“状态管理优化”或“核心重叠算法”，报告中必须提出至少 1 条实质性的重构或优化建议。
- [ ] 报告中指出的每一个问题都 must 附带具体的文件路径和上下文说明。
- [ ] 所有修改建议必须具体可执行（最好提供修改前后的代码片段对比）。
- [ ] （验证机制：由独立的 agent-as-judge 步骤验证报告是否生成，且是否符合上述所有高标准质量要求。）
