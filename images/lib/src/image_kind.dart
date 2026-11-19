import 'dart:typed_data';

/// The kinds of picture the app takes, each with the extension its files
/// get.
enum ImageKind {
  jpeg('jpg'),
  png('png'),
  gif('gif'),
  webp('webp'),
  bmp('bmp');

  const ImageKind(this.extension);

  /// Without the dot, e.g. `jpg`.
  final String extension;

  /// The kind [bytes] are, by their first bytes, whatever their name
  /// says; `null` for any other (e.g. HEIC, SVG).
  static ImageKind? of(Uint8List bytes) {
    bool startsWith(List<int> start, [int at = 0]) =>
        bytes.length >= at + start.length &&
        start.indexed.every((entry) => bytes[at + entry.$1] == entry.$2);
    return switch (bytes) {
      _ when startsWith(const [0xFF, 0xD8, 0xFF]) => jpeg,
      _ when startsWith(const [0x89, 0x50, 0x4E, 0x47]) => png,
      _ when startsWith('GIF8'.codeUnits) => gif,
      _ when startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8) =>
        webp,
      _ when startsWith('BM'.codeUnits) => bmp,
      _ => null,
    };
  }
}
