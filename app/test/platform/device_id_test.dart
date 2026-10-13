import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';

import '../support.dart';

void main() {
  test('makes a random id once and keeps it', () async {
    final storage = AppStorage(tempFolder().path);

    final first = await loadDeviceId(storage);

    expect(first, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(await loadDeviceId(storage), first);
    expect(await loadDeviceId(AppStorage(tempFolder().path)), isNot(first));
  });

  test('replaces a damaged id', () async {
    final storage = AppStorage(tempFolder().path);
    File('${storage.settingsPath}/device_id')
      ..createSync(recursive: true)
      ..writeAsStringSync('../oops');

    expect(await loadDeviceId(storage), matches(RegExp(r'^[0-9a-f]{16}$')));
  });
}
