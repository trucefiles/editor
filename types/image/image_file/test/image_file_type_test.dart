import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_image_file/truce_image_file.dart';

void main() {
  final types = ShownFileTypes([const ImageFileType()]);

  test('is every picture kind the app shows, in any case', () {
    for (final name in [
      'a.jpg',
      'a.JPEG',
      'a.png',
      'a.gif',
      'a.webp',
      'a.bmp',
    ]) {
      expect(
        types.of(RelPath.parse(name)!),
        isA<ImageFileType>(),
        reason: name,
      );
    }
    expect(types.of(RelPath.parse('a.heic')!), isNull);
    expect(types.of(RelPath.parse('a.svg')!), isNull);
  });

  test('is never read for search, not edited, and does not merge', () {
    const type = ImageFileType();

    expect(type.searchText, isNull);
    expect(type.edited, isFalse);
    expect(type.merge, isNull);
  });
}
