import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// The generic filter on a made-up sync tool; Syncthing's own names are
/// tested in the Syncthing package.
void main() {
  final filter = VisibleFileFilter(const FakeSyncRules().isInternal);

  test('includes visible folders only', () {
    expect(filter.includesFolder(path('lists')), isTrue);
    expect(filter.includesFolder(path('a/b/c')), isTrue);
    expect(filter.includesFolder(path('lists/.git')), isFalse);
    expect(filter.includesFolder(path('a/b/.git')), isFalse);
  });

  test("leaves out the sync tool's own folders", () {
    expect(filter.includesFolder(path('.fake')), isFalse);
    expect(filter.includesFolder(path('a/b/.fake')), isFalse);
    expect(filter.includesFile(path('a/.fake/b/todo.md')), isFalse);
  });

  test('includes visible files only', () {
    expect(filter.includesFile(path('lists/todo.md')), isTrue);
    expect(filter.includesFile(path('a/b/c/todo.md')), isTrue);
    expect(filter.includesFile(path('.hidden.md')), isFalse);
    expect(filter.includesFile(path('a/b/.hidden.md')), isFalse);
    expect(filter.includesFile(path('photo.jpg')), isTrue);
  });

  test("leaves out the sync tool's own files", () {
    expect(filter.includesFile(path('todo.md.1234.fake-tmp')), isFalse);
  });
}
