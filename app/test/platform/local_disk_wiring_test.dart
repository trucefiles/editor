import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/platform/platform_wiring.dart';

void main() {
  late LocalDisk disk;

  setUp(() => disk = ProviderContainer.test().read(localDiskProvider));

  test('folders from the Flatpak document portal report no changes', () {
    expect(disk.followsLive('/run/user/1000/doc/1a2b3c/Documents'), isFalse);
    expect(disk.followsLive('/run/flatpak/doc/1a2b3c/Documents'), isFalse);
  });

  test('folders opened directly report changes on Linux', () {
    expect(disk.followsLive('/home/me/Sync/Documents'), Platform.isLinux);
  });

  test('parents of folders from the Flatpak document portal are hidden', () {
    expect(disk.seesParents('/run/user/1000/doc/1a2b3c/Documents'), isFalse);
    expect(disk.seesParents('/run/flatpak/doc/1a2b3c/Documents'), isFalse);
  });

  test('parents of other folders can be read', () {
    expect(disk.seesParents('/home/me/Sync/Documents'), isTrue);
    expect(disk.seesParents('/storage/emulated/0/Sync'), isTrue);
    expect(disk.seesParents('/run/media/me/usb/doc/Documents'), isTrue);
  });
}
