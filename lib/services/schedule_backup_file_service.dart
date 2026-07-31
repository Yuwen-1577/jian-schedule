import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

typedef BackupFileWriter = Future<void> Function(String path, Uint8List bytes);

class ScheduleBackupFileService {
  ScheduleBackupFileService({
    required FilePicker filePicker,
    required bool pickerWritesBytes,
    BackupFileWriter? fileWriter,
  }) : _filePicker = filePicker,
       _pickerWritesBytes = pickerWritesBytes,
       _fileWriter = fileWriter ?? _writeFile;

  factory ScheduleBackupFileService.platform() {
    return ScheduleBackupFileService(
      filePicker: FilePicker.platform,
      pickerWritesBytes: Platform.isAndroid || Platform.isIOS,
    );
  }

  final FilePicker _filePicker;
  final bool _pickerWritesBytes;
  final BackupFileWriter _fileWriter;

  Future<bool> saveJson({
    required String jsonContent,
    required String fileName,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonContent));
    final outputPath = await _filePicker.saveFile(
      dialogTitle: '保存课表备份',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: _pickerWritesBytes ? bytes : null,
      lockParentWindow: true,
    );
    if (outputPath == null) return false;

    if (!_pickerWritesBytes) {
      await _fileWriter(outputPath, bytes);
    }
    return true;
  }

  static Future<void> _writeFile(String path, Uint8List bytes) {
    return File(path).writeAsBytes(bytes, flush: true);
  }
}
