import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

typedef UserFileWriter = Future<void> Function(String path, Uint8List bytes);

class UserFileSaveService {
  UserFileSaveService({
    required FilePicker filePicker,
    required bool pickerWritesBytes,
    UserFileWriter? fileWriter,
  }) : _filePicker = filePicker,
       _pickerWritesBytes = pickerWritesBytes,
       _fileWriter = fileWriter ?? _writeFile;

  factory UserFileSaveService.platform() {
    return UserFileSaveService(
      filePicker: FilePicker.platform,
      pickerWritesBytes: Platform.isAndroid || Platform.isIOS,
    );
  }

  final FilePicker _filePicker;
  final bool _pickerWritesBytes;
  final UserFileWriter _fileWriter;

  Future<bool> saveText({
    required String content,
    required String fileName,
    required String dialogTitle,
    required String extension,
  }) {
    return saveBytes(
      bytes: Uint8List.fromList(utf8.encode(content)),
      fileName: fileName,
      dialogTitle: dialogTitle,
      extension: extension,
    );
  }

  Future<bool> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String dialogTitle,
    required String extension,
  }) async {
    final outputPath = await _filePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
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
