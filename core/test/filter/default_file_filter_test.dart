import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/test_helpers.dart';

void main() {
  const filter = DefaultFileFilter(
    SyncthingAdapter(),
    ExtensionFileTypeDetector.standard(),
  );

  test('includes visible folders only', () {
    expect(filter.includesFolder(path('lists')), isTrue);
    expect(filter.includesFolder(path('lists/.git')), isFalse);
    expect(filter.includesFolder(path('.stversions')), isFalse);
  });

  test('includes visible files of a known type only', () {
    expect(filter.includesFile(path('lists/todo.md')), isTrue);
    expect(filter.includesFile(path('photo.jpg')), isFalse);
    expect(filter.includesFile(path('.hidden.md')), isFalse);
    expect(filter.includesFile(path('.syncthing.todo.md.tmp')), isFalse);
  });
}
