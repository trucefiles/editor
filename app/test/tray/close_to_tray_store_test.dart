import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/tray/close_to_tray_store.dart';

import '../support.dart';

void main() {
  late File file;
  late CloseToTrayStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/tray.json');
    store = CloseToTrayStore(file);
  });

  test('is on until the user turns it off', () async {
    expect(await store.load(), isTrue);
  });

  test('keeps the setting', () async {
    await store.save(enabled: false);
    expect(await store.load(), isFalse);

    await store.save(enabled: true);
    expect(await store.load(), isTrue);
  });

  test('falls back to on for an unreadable file', () async {
    file.writeCreatingFolders('{not json');

    expect(await store.load(), isTrue);
  });
}
