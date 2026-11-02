import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/linux/linux_zone.dart';

void main() {
  test('Linux passes on the zone the system names', () async {
    expect(await linuxZone(() async => 'Europe/Berlin')(), 'Europe/Berlin');
    expect(await linuxZone(() async => 'Etc/UTC')(), 'Etc/UTC');
    expect(await linuxZone(() async => null)(), isNull);
  });

  test("Linux's UTC, named when it can't tell, is unknown", () async {
    expect(await linuxZone(() async => 'UTC')(), isNull);
  });
}
