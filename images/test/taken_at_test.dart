import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:truce_images/src/taken_at.dart';

/// A tiny JPEG whose EXIF says it was taken at [original], and last
/// changed at [changed].
Uint8List _photo({String? original, String? changed}) {
  final image = img.Image(width: 2, height: 2);
  if (original != null) image.exif.exifIfd['DateTimeOriginal'] = original;
  if (changed != null) image.exif.imageIfd['DateTime'] = changed;
  return img.encodeJpg(image);
}

void main() {
  test('reads when a photo was taken', () {
    expect(
      takenAt(_photo(original: '2026:11:21 18:04:35')),
      DateTime(2026, 11, 21, 18, 4, 35),
    );
  });

  test('falls back to when the photo was last changed', () {
    expect(
      takenAt(_photo(changed: '2025:01:02 03:04:05')),
      DateTime(2025, 1, 2, 3, 4, 5),
    );
  });

  test('says nothing without a date, with a blank one, or for no JPEG', () {
    expect(takenAt(_photo()), isNull);
    expect(takenAt(_photo(original: '0000:00:00 00:00:00')), isNull);
    expect(takenAt(img.encodePng(img.Image(width: 1, height: 1))), isNull);
    expect(takenAt(Uint8List.fromList([0xFF, 0xD8, 1, 2])), isNull);
  });
}
