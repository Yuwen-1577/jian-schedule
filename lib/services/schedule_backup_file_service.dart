import 'package:file_picker/file_picker.dart';

import 'user_file_save_service.dart';

typedef BackupFileWriter = UserFileWriter;

class ScheduleBackupFileService {
  ScheduleBackupFileService({
    required FilePicker filePicker,
    required bool pickerWritesBytes,
    BackupFileWriter? fileWriter,
  }) : _fileSaveService = UserFileSaveService(
         filePicker: filePicker,
         pickerWritesBytes: pickerWritesBytes,
         fileWriter: fileWriter,
       );

  factory ScheduleBackupFileService.platform() {
    return ScheduleBackupFileService._(UserFileSaveService.platform());
  }

  ScheduleBackupFileService._(this._fileSaveService);

  final UserFileSaveService _fileSaveService;

  Future<bool> saveJson({
    required String jsonContent,
    required String fileName,
  }) {
    return _fileSaveService.saveText(
      content: jsonContent,
      fileName: fileName,
      dialogTitle: '保存课表备份',
      extension: 'json',
    );
  }
}
