import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/storage/app_storage.dart';

const _rules = 'android/app/src/main/res/xml';

String _read(String path) => File(path).readAsStringSync();

/// Every list of things Android leaves out: the cloud backup and the move
/// to a new phone (Android 12 and later), and the backup of older Androids.
Map<String, String> _excludeLists() {
  final extraction = _read('$_rules/data_extraction_rules.xml');
  return {
    for (final section in ['cloud-backup', 'device-transfer'])
      section: RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(extraction)![1]!,
    'backup_rules': _read('$_rules/backup_rules.xml'),
  };
}

void _expectLeftOut(String exclude) {
  for (final MapEntry(key: name, value: body) in _excludeLists().entries) {
    expect(body, contains(exclude), reason: name);
  }
}

void main() {
  test("this device's id is never backed up or moved to a new phone", () {
    final storage = AppStorage('/data/files');
    final relative = storage.deviceIdPath.substring('/data/files/'.length);
    final manifest = _read('android/app/src/main/AndroidManifest.xml');

    expect(
      manifest,
      contains('dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(manifest, contains('fullBackupContent="@xml/backup_rules"'));
    _expectLeftOut('<exclude domain="file" path="$relative" />');
  });

  test('alerts handed to the system are never backed up or moved to a new '
      'phone, so old ones cannot ring there', () {
    _expectLeftOut('<exclude domain="file" path="settings/ring_state.json" />');
    _expectLeftOut(
      '<exclude domain="sharedpref" path="scheduled_notifications.xml" />',
    );
  });

  test('drafts and backups are never backed up or moved to a new phone, '
      'so old edits cannot land in synced folders there', () {
    final storage = AppStorage('/data/files');
    String relative(String path) => path.substring('/data/files/'.length);

    _expectLeftOut(
      '<exclude domain="file" path="${relative(storage.draftsRootPath)}" />',
    );
    _expectLeftOut(
      '<exclude domain="file" path="${relative(storage.backupsRootPath)}" />',
    );
  });
}
