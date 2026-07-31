import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/services/edu_import/edu_import_diagnostic_export_service.dart';
import 'package:simple_schedule/services/edu_import/edu_import_diagnostics.dart';
import 'package:simple_schedule/services/user_file_save_service.dart';

void main() {
  const diagnostics = EduImportDiagnostics(
    documents: [],
    ruleAttempts: [],
    sanitizedDocuments: [],
    blockedCrossOriginFrameCount: 0,
    truncated: false,
  );

  test('安全结构报告通过系统保存器写入 UTF-8 JSON', () async {
    final picker = _FakeFilePicker(result: '/document/report.json');
    final service = EduImportDiagnosticExportService(
      fileSaveService: UserFileSaveService(
        filePicker: picker,
        pickerWritesBytes: true,
      ),
      clock: () => DateTime(2026, 7, 31, 9, 8, 7),
    );

    final fileName = await service.save(
      diagnostics,
      EduImportDiagnosticLevel.structure,
    );

    expect(fileName, 'jian_schedule_edu_structure_20260731_090807.json');
    expect(picker.receivedFileName, fileName);
    expect(picker.receivedExtensions, ['json']);
    final decoded =
        jsonDecode(utf8.decode(picker.receivedBytes!)) as Map<String, dynamic>;
    expect(decoded['reportType'], 'structure');
  });

  test('深度脱敏报告使用 HTML 扩展名且不自动上传', () async {
    final picker = _FakeFilePicker(result: '/document/report.html');
    final service = EduImportDiagnosticExportService(
      fileSaveService: UserFileSaveService(
        filePicker: picker,
        pickerWritesBytes: true,
      ),
      clock: () => DateTime(2026, 8, 1, 1, 2, 3),
    );

    final fileName = await service.save(
      diagnostics,
      EduImportDiagnosticLevel.sanitizedHtml,
    );

    expect(fileName, 'jian_schedule_edu_sanitized_20260801_010203.html');
    expect(picker.receivedExtensions, ['html']);
    expect(utf8.decode(picker.receivedBytes!), contains('简课表深度脱敏诊断'));
  });

  test('用户取消系统保存界面时返回 null', () async {
    final service = EduImportDiagnosticExportService(
      fileSaveService: UserFileSaveService(
        filePicker: _FakeFilePicker(result: null),
        pickerWritesBytes: true,
      ),
    );

    final fileName = await service.save(
      diagnostics,
      EduImportDiagnosticLevel.structure,
    );

    expect(fileName, isNull);
  });
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({required this.result});

  final String? result;
  String? receivedFileName;
  List<String>? receivedExtensions;
  Uint8List? receivedBytes;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    receivedFileName = fileName;
    receivedExtensions = allowedExtensions;
    receivedBytes = bytes;
    return result;
  }
}
