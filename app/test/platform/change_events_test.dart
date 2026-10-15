import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/change_events.dart';

void main() {
  test('folders from the Flatpak document portal report no changes', () {
    expect(reportsChanges('/run/user/1000/doc/1a2b3c/Notes'), isFalse);
    expect(reportsChanges('/run/flatpak/doc/1a2b3c/Notes'), isFalse);
  });

  test('folders opened directly report changes on Linux', () {
    expect(reportsChanges('/home/me/Sync/Notes'), Platform.isLinux);
  });
}
