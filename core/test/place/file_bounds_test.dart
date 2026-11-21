import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  final bounds = FileBounds(
    handles: (file) => file.name.endsWith('.png'),
    keptApart: (path) => path.isAtOrInside(RelPath.parse('kept')!),
  );

  test('shows the files it handles', () {
    expect(bounds.shows(RelPath.parse('a.png')!), isTrue);
    expect(bounds.shows(RelPath.parse('a.pdf')!), isFalse);
  });

  test('never shows a file kept apart, though it handles it', () {
    expect(bounds.shows(RelPath.parse('kept/a.png')!), isFalse);
  });
}
