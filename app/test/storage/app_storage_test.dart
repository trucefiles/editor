import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';

void main() {
  test("this device's id is never backed up or moved to a new phone", () {
    const rules = 'android/app/src/main/res/xml';
    final storage = AppStorage('/data/files');
    final relative = storage.deviceIdPath.substring('/data/files/'.length);
    final exclude = '<exclude domain="file" path="$relative" />';
    String read(String path) => File(path).readAsStringSync();

    final manifest = read('android/app/src/main/AndroidManifest.xml');
    final extraction = read('$rules/data_extraction_rules.xml');
    final backup = read('$rules/backup_rules.xml');

    expect(
      manifest,
      contains('dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifest, contains('fullBackupContent="@xml/backup_rules"'));
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(extraction)![1]!;
      expect(body, contains(exclude), reason: section);
    }
    expect(backup, contains(exclude));
  });
}
