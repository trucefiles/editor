import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/parent_folder_access.dart';

void main() {
  test('parents of folders from the Flatpak document portal are hidden', () {
    expect(canReadParents('/run/user/1000/doc/1a2b3c/Notes'), isFalse);
    expect(canReadParents('/run/flatpak/doc/1a2b3c/Notes'), isFalse);
  });

  test('parents of other folders can be read', () {
    expect(canReadParents('/home/me/Sync/Notes'), isTrue);
    expect(canReadParents('/storage/emulated/0/Sync'), isTrue);
    expect(canReadParents('/run/media/me/usb/doc/Notes'), isTrue);
  });
}
