import 'package:test/test.dart';
import 'package:truce_core/testing.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

void main() {
  const filter = DefaultFileFilter(
    SyncthingAdapter(),
    ExtensionFileTypeDetector.standard(),
  );

  test('includes visible folders only', () {
    expect(filter.includesFolder(path('lists')), isTrue);
    expect(filter.includesFolder(path('lists/.git')), isFalse);
    expect(filter.includesFolder(path('.stversions')), isFalse);
    expect(filter.includesFolder(path('a/b/c')), isTrue);
    expect(filter.includesFolder(path('a/b/.git')), isFalse);
    expect(filter.includesFolder(path('a/b/.stversions')), isFalse);
  });

  test('includes visible files of a known type only', () {
    expect(filter.includesFile(path('lists/todo.md')), isTrue);
    expect(filter.includesFile(path('a/b/c/todo.md')), isTrue);
    expect(filter.includesFile(path('a/b/.hidden.md')), isFalse);
    expect(filter.includesFile(path('a/.stversions/b/todo.md')), isFalse);
    expect(filter.includesFile(path('photo.jpg')), isFalse);
    expect(filter.includesFile(path('.hidden.md')), isFalse);
    expect(filter.includesFile(path('.syncthing.todo.md.tmp')), isFalse);
    expect(
      filter.includesFile(
        path('todo.sync-conflict-20261003-134809-4I343AW.md'),
      ),
      isFalse,
    );
  });
}
