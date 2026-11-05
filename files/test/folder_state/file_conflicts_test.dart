import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// Folder `notes`, listed with a pending conflict of each of [conflicts].
FolderState _listed(List<String> conflicts) => FolderState({
  folderId('notes'): Listed(
    FolderFound(
      files: const {},
      conflicts: {
        for (final main in conflicts)
          path(main): Conflict(
            mainPath: path(main),
            main: null,
            copies: const [],
          ),
      },
      subfolders: const {},
      unreadable: const [],
      marks: MarksFiles.none,
    ),
    listedAt: Moment.now(),
  ),
});

FileKey _key(String name, {String folder = 'notes'}) =>
    (folder: folderId(folder), path: path(name));

void main() {
  group('conflictWaitsIn', () {
    test('a listed conflict of the file waits', () {
      expect(conflictWaitsIn(_listed(['todo.md']), _key('todo.md')), isTrue);
    });

    test('no conflict of the file waits when none is listed for it', () {
      expect(conflictWaitsIn(_listed(['other.md']), _key('todo.md')), isFalse);
    });

    test('nothing waits in a folder that is not listed', () {
      final state = FolderState({folderId('notes'): const NotListed()});
      expect(conflictWaitsIn(state, _key('todo.md')), isFalse);
    });

    test('nothing waits in an unknown folder', () {
      expect(
        conflictWaitsIn(_listed(['todo.md']), _key('todo.md', folder: 'work')),
        isFalse,
      );
    });
  });
}
