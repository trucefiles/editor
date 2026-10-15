import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/platform_facts.dart';

import '../support.dart';

void main() {
  late PlatformFacts facts;

  setUp(() => facts = hostFacts());

  test('folders from the Flatpak document portal report no changes', () {
    expect(facts.reportsChangesIn('/run/user/1000/doc/1a2b3c/Notes'), isFalse);
    expect(facts.reportsChangesIn('/run/flatpak/doc/1a2b3c/Notes'), isFalse);
  });

  test('folders opened directly report changes on Linux', () {
    expect(facts.reportsChangesIn('/home/me/Sync/Notes'), Platform.isLinux);
  });

  test('parents of folders from the Flatpak document portal are hidden', () {
    expect(facts.canReadParentsOf('/run/user/1000/doc/1a2b3c/Notes'), isFalse);
    expect(facts.canReadParentsOf('/run/flatpak/doc/1a2b3c/Notes'), isFalse);
  });

  test('parents of other folders can be read', () {
    expect(facts.canReadParentsOf('/home/me/Sync/Notes'), isTrue);
    expect(facts.canReadParentsOf('/storage/emulated/0/Sync'), isTrue);
    expect(facts.canReadParentsOf('/run/media/me/usb/doc/Notes'), isTrue);
  });
}
