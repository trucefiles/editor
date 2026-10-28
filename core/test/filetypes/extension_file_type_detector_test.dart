import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final detector = ExtensionFileTypeDetector.of(const [FakeFileType()]);

  test('detects a type by its extensions, ignoring case', () {
    expect(detector.detect(path('todo.md')), FakeFileType.id);
    expect(detector.detect(path('lists/TODO.MD')), FakeFileType.id);
  });

  test('returns null for unknown or missing extensions', () {
    for (final raw in ['photo.jpg', 'Makefile', '.md', 'md']) {
      expect(detector.detect(path(raw)), isNull, reason: raw);
    }
  });

  test('two types may not share an extension', () {
    expect(
      () =>
          ExtensionFileTypeDetector.of(const [FakeFileType(), FakeFileType()]),
      throwsA(isA<AssertionError>()),
    );
  });
}
