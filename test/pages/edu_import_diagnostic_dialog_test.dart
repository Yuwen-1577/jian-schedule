import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/pages/edu_import/edu_import_diagnostic_dialog.dart';
import 'package:simple_schedule/services/edu_import/edu_import_diagnostics.dart';

void main() {
  testWidgets('安全结构报告是推荐选项且无需二次确认', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('选择诊断级别'));
    await tester.pumpAndSettle();

    expect(find.text('报告只在本机生成，不会自动上传或分享。'), findsOneWidget);
    expect(find.text('推荐'), findsOneWidget);

    await tester.tap(find.text('安全结构报告'));
    await tester.pumpAndSettle();

    expect(find.text('structure'), findsOneWidget);
    expect(find.text('导出深度脱敏页面？'), findsNothing);
  });

  testWidgets('深度脱敏页面必须经过明确二次确认', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('选择诊断级别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深度脱敏页面'));
    await tester.pumpAndSettle();

    expect(find.text('导出深度脱敏页面？'), findsOneWidget);
    expect(find.text('我理解并导出'), findsOneWidget);

    await tester.tap(find.text('我理解并导出'));
    await tester.pumpAndSettle();

    expect(find.text('sanitizedHtml'), findsOneWidget);
  });

  testWidgets('取消深度脱敏确认不会导出', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('选择诊断级别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深度脱敏页面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('cancelled'), findsOneWidget);
  });

  testWidgets('保存成功后只提示文件名', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('模拟保存成功'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安全结构报告'));
    await tester.pumpAndSettle();

    expect(find.text('已保存：diagnostic.json'), findsOneWidget);
  });

  testWidgets('保存失败时显示可重试提示', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('模拟保存失败'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('安全结构报告'));
    await tester.pumpAndSettle();

    expect(find.text('保存诊断失败，请重试'), findsOneWidget);
  });
  testWidgets('完全解析失败提示可选择保存诊断', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _DialogHarness()));

    await tester.tap(find.text('模拟无课程'));
    await tester.pumpAndSettle();

    expect(find.text('没有识别到课程'), findsOneWidget);
    expect(find.text('保存诊断'), findsOneWidget);

    await tester.tap(find.text('保存诊断'));
    await tester.pumpAndSettle();

    expect(find.text('save-diagnostic'), findsOneWidget);
  });
}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness();

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  String _result = 'idle';

  Future<void> _chooseLevel() async {
    final level = await showEduImportDiagnosticLevelDialog(context);
    if (!mounted) return;
    setState(() => _result = level?.name ?? 'cancelled');
  }

  static const _diagnostics = EduImportDiagnostics(
    documents: [],
    ruleAttempts: [],
    sanitizedDocuments: [],
    blockedCrossOriginFrameCount: 0,
    truncated: false,
  );

  Future<void> _export({required bool fail}) {
    return exportEduImportDiagnostics(
      context: context,
      diagnostics: _diagnostics,
      exporter: (_, _) async {
        if (fail) throw const FormatException('synthetic failure');
        return 'diagnostic.json';
      },
    );
  }

  Future<void> _showNoCourses() async {
    final shouldSave = await showNoEduImportCoursesDialog(context);
    if (!mounted) return;
    setState(() => _result = shouldSave ? 'save-diagnostic' : 'return');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(onPressed: _chooseLevel, child: const Text('选择诊断级别')),
          FilledButton(
            onPressed: () => _export(fail: false),
            child: const Text('模拟保存成功'),
          ),
          FilledButton(
            onPressed: () => _export(fail: true),
            child: const Text('模拟保存失败'),
          ),
          FilledButton(onPressed: _showNoCourses, child: const Text('模拟无课程')),
          Text(_result),
        ],
      ),
    );
  }
}
