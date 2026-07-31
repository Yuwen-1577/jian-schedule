import 'package:intl/intl.dart';

import '../user_file_save_service.dart';
import 'edu_import_diagnostics.dart';

typedef EduImportDiagnosticExportCallback =
    Future<String?> Function(
      EduImportDiagnostics diagnostics,
      EduImportDiagnosticLevel level,
    );

class EduImportDiagnosticExportService {
  EduImportDiagnosticExportService({
    required UserFileSaveService fileSaveService,
    DateTime Function()? clock,
  }) : _fileSaveService = fileSaveService,
       _clock = clock ?? DateTime.now;

  factory EduImportDiagnosticExportService.platform() {
    return EduImportDiagnosticExportService(
      fileSaveService: UserFileSaveService.platform(),
    );
  }

  final UserFileSaveService _fileSaveService;
  final DateTime Function() _clock;

  Future<String?> save(
    EduImportDiagnostics diagnostics,
    EduImportDiagnosticLevel level,
  ) async {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(_clock());
    final isStructure = level == EduImportDiagnosticLevel.structure;
    final fileName = isStructure
        ? 'jian_schedule_edu_structure_$timestamp.json'
        : 'jian_schedule_edu_sanitized_$timestamp.html';
    final saved = await _fileSaveService.saveText(
      content: isStructure
          ? diagnostics.toStructureJson()
          : diagnostics.toSanitizedHtml(),
      fileName: fileName,
      dialogTitle: isStructure ? '保存安全结构报告' : '保存深度脱敏页面',
      extension: isStructure ? 'json' : 'html',
    );
    return saved ? fileName : null;
  }
}
