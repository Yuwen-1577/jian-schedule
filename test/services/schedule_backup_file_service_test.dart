import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_schedule/services/schedule_backup_file_service.dart';

void main() {
  const jsonContent = '{"课程":"高等数学","count":2}';

  test('移动端通过系统保存器直接写入 UTF-8 JSON', () async {
    final picker = _FakeFilePicker(result: '/document/backup.json');
    var writerCalled = false;
    final service = ScheduleBackupFileService(
      filePicker: picker,
      pickerWritesBytes: true,
      fileWriter: (_, _) async => writerCalled = true,
    );

    final saved = await service.saveJson(
      jsonContent: jsonContent,
      fileName: 'backup.json',
    );

    expect(saved, isTrue);
    expect(writerCalled, isFalse);
    expect(picker.receivedFileName, 'backup.json');
    expect(jsonDecode(utf8.decode(picker.receivedBytes!)), {
      '课程': '高等数学',
      'count': 2,
    });
  });

  test('桌面端选择路径后写入 JSON', () async {
    final picker = _FakeFilePicker(result: 'D:/backup.json');
    String? writtenPath;
    Uint8List? writtenBytes;
    final service = ScheduleBackupFileService(
      filePicker: picker,
      pickerWritesBytes: false,
      fileWriter: (path, bytes) async {
        writtenPath = path;
        writtenBytes = bytes;
      },
    );

    final saved = await service.saveJson(
      jsonContent: jsonContent,
      fileName: 'backup.json',
    );

    expect(saved, isTrue);
    expect(picker.receivedBytes, isNull);
    expect(writtenPath, 'D:/backup.json');
    expect(utf8.decode(writtenBytes!), jsonContent);
  });

  test('用户取消保存时不写文件', () async {
    final picker = _FakeFilePicker(result: null);
    var writerCalled = false;
    final service = ScheduleBackupFileService(
      filePicker: picker,
      pickerWritesBytes: false,
      fileWriter: (_, _) async => writerCalled = true,
    );

    final saved = await service.saveJson(
      jsonContent: jsonContent,
      fileName: 'backup.json',
    );

    expect(saved, isFalse);
    expect(writerCalled, isFalse);
  });

  test('桌面写入失败会向上抛出', () async {
    final service = ScheduleBackupFileService(
      filePicker: _FakeFilePicker(result: 'D:/backup.json'),
      pickerWritesBytes: false,
      fileWriter: (_, _) => throw const FileSystemException('write failed'),
    );

    expect(
      () => service.saveJson(jsonContent: jsonContent, fileName: 'backup.json'),
      throwsA(isA<FileSystemException>()),
    );
  });
}

class _FakeFilePicker extends FilePicker {
  _FakeFilePicker({required this.result});

  final String? result;
  String? receivedFileName;
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
    receivedBytes = bytes;
    return result;
  }
}
