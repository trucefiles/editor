import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/test_helpers.dart';

void main() {
  const detector = ExtensionFileTypeDetector.standard();

  test('detects Markdown by extension, ignoring case', () {
    expect(detector.detect(path('todo.md')), markdownFileType);
    expect(detector.detect(path('lists/TODO.MD')), markdownFileType);
  });

  test('returns null for unknown or missing extensions', () {
    for (final raw in ['photo.jpg', 'Makefile', '.md', 'md']) {
      expect(detector.detect(path(raw)), isNull, reason: raw);
    }
  });
}
