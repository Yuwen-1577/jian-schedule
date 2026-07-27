import 'package:flutter/material.dart';

import '../../models/course.dart';
import '../../services/edu_import/edu_import_commit_service.dart';
import '../../services/edu_import/edu_import_models.dart';
import '../../utils/constants.dart';

class EduImportPreviewPage extends StatefulWidget {
  const EduImportPreviewPage({
    super.key,
    required this.batch,
    required this.existingCourses,
    required this.scheduleSetName,
  });

  final EduImportBatch batch;
  final List<Course> existingCourses;
  final String scheduleSetName;

  @override
  State<EduImportPreviewPage> createState() => _EduImportPreviewPageState();
}

class _EduImportPreviewPageState extends State<EduImportPreviewPage> {
  ImportMode _mode = ImportMode.append;

  int get _duplicateCount => EduImportCommitService.duplicateCount(
    batch: widget.batch,
    existingCourses: widget.existingCourses,
  );

  Future<void> _continueImport() async {
    if (_mode == ImportMode.replace) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('替换当前课表？'),
          content: Text(
            '将删除“${widget.scheduleSetName}”现有的 '
            '${widget.existingCourses.length} 门课程，再写入本次有效课程。'
            '\n\n学期日期、节次时间和其他课表集不会改变。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('确认替换'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    Navigator.pop(context, _mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validDrafts = widget.batch.validDrafts;
    final invalidDrafts = widget.batch.invalidDrafts;

    return Scaffold(
      appBar: AppBar(title: const Text('导入预览')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            '解析完成',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.batch.parserVersions.isEmpty
                ? '未识别到可用的强智课表结构'
                : widget.batch.parserVersions.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip(
                label: '有效',
                count: validDrafts.length,
                color: theme.colorScheme.primary,
              ),
              _CountChip(
                label: '重复',
                count: _duplicateCount,
                color: theme.colorScheme.tertiary,
              ),
              _CountChip(
                label: '无效',
                count: invalidDrafts.length,
                color: theme.colorScheme.error,
              ),
            ],
          ),
          if (widget.batch.blockedCrossOriginFrameCount > 0) ...[
            const SizedBox(height: 12),
            _NoticeCard(
              icon: Icons.info_outline,
              message:
                  '有 ${widget.batch.blockedCrossOriginFrameCount} 个跨域框架无法读取。'
                  '若课程不完整，请在框架内打开课表后重试。',
            ),
          ],
          const SizedBox(height: 24),
          Text('写入方式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ImportMode>(
            segments: const [
              ButtonSegment(
                value: ImportMode.append,
                icon: Icon(Icons.add_circle_outline),
                label: Text('仅新增'),
              ),
              ButtonSegment(
                value: ImportMode.replace,
                icon: Icon(Icons.sync),
                label: Text('替换当前课表'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) {
              setState(() => _mode = selection.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _mode == ImportMode.append
                ? '保留现有课程，完全相同的课程会自动跳过。'
                : '只替换“${widget.scheduleSetName}”中的课程；其他设置不变。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _mode == ImportMode.replace
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('有效课程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (validDrafts.isEmpty)
            const _NoticeCard(
              icon: Icons.search_off,
              message: '没有可以导入的课程。请返回网页确认已打开课表页面。',
            )
          else
            ...validDrafts.map((draft) => _CoursePreviewCard(draft: draft)),
          if (invalidDrafts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('需要检查', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...invalidDrafts.map(
              (draft) => _CoursePreviewCard(draft: draft, invalid: true),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: validDrafts.isEmpty ? null : _continueImport,
            icon: const Icon(Icons.check),
            label: Text(_mode == ImportMode.append ? '导入有效课程' : '替换当前课表课程'),
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _CoursePreviewCard extends StatelessWidget {
  const _CoursePreviewCard({required this.draft, this.invalid = false});

  final ImportedCourseDraft draft;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayText = draft.day == null ? '星期未知' : weekdayNames[draft.day! - 1];
    final periodText = draft.startPeriod == null || draft.duration == null
        ? '节次未知'
        : '第 ${draft.startPeriod}-${draft.startPeriod! + draft.duration! - 1} 节';
    final weeksText = draft.activeWeeks.isEmpty
        ? '周次未知'
        : _formatWeeks(draft.activeWeeks);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.name.isEmpty ? '未命名课程' : draft.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (invalid)
                  Icon(
                    Icons.error_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$dayText · $periodText · $weeksText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (draft.teacher.isNotEmpty || draft.room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  draft.teacher,
                  draft.room,
                ].where((part) => part.isNotEmpty).join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (invalid) ...[
              const SizedBox(height: 8),
              Text(
                draft.validationIssues.join('；'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatWeeks(List<int> weeks) {
    final sorted = List<int>.from(weeks)..sort();
    return '${sorted.join('、')} 周';
  }
}
