import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android 仅 Debug 清单允许 HTTP 明文流量', () {
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(mainManifest, isNot(contains('usesCleartextTraffic')));
  });

  test('教务导入源码不记录网页、Cookie 或账号内容', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains('edu_import') && file.path.endsWith('.dart'),
        );

    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        RegExp(
          r'(^|[^A-Za-z])(?:debugPrint|print)\s*\(',
          multiLine: true,
        ).hasMatch(source),
        isFalse,
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('jwgl.example')),
        reason: '不能在源码内预置完整教务网址：${file.path}',
      );
    }
  });
}
