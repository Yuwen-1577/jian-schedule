import 'package:flutter/material.dart';

import '../../services/edu_import/edu_import_diagnostics.dart';

Future<void> exportEduImportDiagnostics({
  required BuildContext context,
  required EduImportDiagnostics diagnostics,
  required Future<String?> Function(
    EduImportDiagnostics diagnostics,
    EduImportDiagnosticLevel level,
  )
  exporter,
}) async {
  final level = await showEduImportDiagnosticLevelDialog(context);
  if (level == null || !context.mounted) return;

  try {
    final fileName = await exporter(diagnostics, level);
    if (fileName != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已保存：$fileName')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存诊断失败，请重试')));
    }
  }
}

Future<EduImportDiagnosticLevel?> showEduImportDiagnosticLevelDialog(
  BuildContext context,
) async {
  final selected = await showDialog<EduImportDiagnosticLevel>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('导出解析诊断'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('报告只在本机生成，不会自动上传或分享。'),
            const SizedBox(height: 16),
            _DiagnosticLevelTile(
              icon: Icons.security_outlined,
              title: '安全结构报告',
              subtitle: '仅含标签、表格尺寸和解析统计，不含网页文字或属性值。',
              recommended: true,
              onTap: () =>
                  Navigator.pop(context, EduImportDiagnosticLevel.structure),
            ),
            const SizedBox(height: 8),
            _DiagnosticLevelTile(
              icon: Icons.code_outlined,
              title: '深度脱敏页面',
              subtitle: '保留静态 DOM 特征，适配效率更高，但会暴露页面技术结构。',
              onTap: () => Navigator.pop(
                context,
                EduImportDiagnosticLevel.sanitizedHtml,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    ),
  );
  if (selected != EduImportDiagnosticLevel.sanitizedHtml || !context.mounted) {
    return selected;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('导出深度脱敏页面？'),
      content: const Text(
        '文件会移除网址、账号、Cookie、课程名、教师、教室和表单输入，'
        '但仍保留部分 class、id、name 与表格结构，可能暴露学校系统的技术特征。'
        '\n\n文件不会自动上传；发送给他人前请再次自行检查。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('我理解并导出'),
        ),
      ],
    ),
  );
  return confirmed == true ? selected : null;
}

Future<bool> showNoEduImportCoursesDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('没有识别到课程'),
          content: const Text(
            '请确认已经登录，并打开“我的课表”或“班级课表”页面。'
            '\n\n不同学校页面结构可能不同；你可以保存不含账号、网址和课程内容的诊断报告，帮助后续适配。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存诊断'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回检查'),
            ),
          ],
        ),
      ) ??
      false;
}

class _DiagnosticLevelTile extends StatelessWidget {
  const _DiagnosticLevelTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.recommended = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: '$title，$subtitle',
        child: ListTile(
          minTileHeight: 64,
          leading: Icon(icon),
          title: Row(
            children: [
              Flexible(child: Text(title)),
              if (recommended) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '推荐',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
