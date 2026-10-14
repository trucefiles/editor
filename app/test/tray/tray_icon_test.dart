import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/tray/tray_icon.dart';

void main() {
  test('turns RGBA pixels into ARGB', () {
    final icon = TrayIcon.fromRgba(
      2,
      1,
      Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
    );

    expect(icon.width, 2);
    expect(icon.height, 1);
    expect(icon.argb, [4, 1, 2, 3, 8, 5, 6, 7]);
  });
}
