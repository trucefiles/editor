import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// When [bytes], a photo, was taken, as its camera wrote it (local
/// time); `null` where it doesn't say: not a JPEG, or no readable date.
DateTime? takenAt(Uint8List bytes) {
  final written = _writtenDate(bytes);
  return written == null ? null : _exifDate(written);
}

/// The date [bytes] say they were taken, as written; the `image` package
/// throws on EXIF data it can't read.
String? _writtenDate(Uint8List bytes) {
  try {
    final exif = img.decodeJpgExif(bytes);
    return (exif?.exifIfd['DateTimeOriginal'] ?? exif?.imageIfd['DateTime'])
        ?.toString();
  } on Object {
    return null;
  }
}

final _exifDatePattern = RegExp(
  r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})',
);

/// [text] in EXIF's form, e.g. `2026:11:21 18:04:35`; `null` for
/// another form or a blank date (`0000:00:00 00:00:00`).
DateTime? _exifDate(String text) {
  final match = _exifDatePattern.firstMatch(text.trim());
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (final group in Iterable<int>.generate(6, (index) => index + 1))
      int.parse(match[group]!),
  ];
  if (year == 0 || month == 0 || day == 0) return null;
  return DateTime(year, month, day, hour, minute, second);
}
