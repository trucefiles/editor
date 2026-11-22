import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('the save icon shows where a shown file is', () {
    final folder = Folder(
      id: folderId('home'),
      name: 'home',
      color: 'teal',
      location: 'fake:home',
    );
    final photo = NewShownFile(
      topOf(folder),
      name: 'Photo.jpg',
      bytes: Uint8List.fromList([1]),
    );
    final listed = ListedFile(
      folder: folder,
      path: path('Photo.jpg'),
      type: const FakeFileType(),
      version: FileVersion(0),
      modified: DateTime(2000),
      size: 0,
    );
    final content = ContentTag.unique();
    final cases = <ShownState, SaveState>{
      WaitingNew(photo, kept: NewKept.keeping, content: content):
          SaveState.none,
      WaitingNew(photo, kept: NewKept.onDevice, content: content):
          SaveState.onDevice,
      WaitingNew(photo, kept: NewKept.nowhere, content: content):
          SaveState.none,
      ShownListed(listed, content: content): SaveState.inFolder,
      ShownGone(listed, content: content): SaveState.none,
      const ShownDropped(): SaveState.none,
    };

    for (final MapEntry(key: state, :value) in cases.entries) {
      expect(saveStateOfShown(state), value, reason: '$state');
    }
  });
}
