import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_store.dart';

import '../support.dart';

void main() {
  late File file;
  late RefreshSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/refresh.json');
    store = RefreshSettingsStore(file);
  });

  test('is the standard setting until the user changes it', () async {
    expect(await store.load(), RefreshSettings.standard);
  });

  test('keeps the setting', () async {
    const manual = RefreshSettings(
      mode: RefreshMode.manual,
      interval: Duration(seconds: 30),
    );

    await store.save(manual);

    expect(await store.load(), manual);
  });

  test('falls back to the standard setting for an unreadable file', () async {
    file.writeCreatingFolders('{not json');

    expect(await store.load(), RefreshSettings.standard);
  });
}
