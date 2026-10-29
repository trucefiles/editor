import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('truce_device_id'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('makes a random id once and keeps it', () async {
    final file = File('${dir.path}/settings/device_id');

    final first = await loadDeviceId(file);

    expect(first, matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(await loadDeviceId(file), first);
    expect(await loadDeviceId(File('${dir.path}/other')), isNot(first));
  });

  test('replaces a damaged id', () async {
    final file = File('${dir.path}/device_id')..writeAsStringSync('../oops');

    expect(await loadDeviceId(file), matches(RegExp(r'^[0-9a-f]{16}$')));
  });
}
