import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_test_support/truce_test_support.dart';

/// Base `notes`, listed with a pending conflict of each of [conflicts].
FolderState _listed(List<String> conflicts) => FolderState({
  'notes': Listed(
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
    listedAt: Moment.now(),
  ),
});

DocumentKey _key(String name, {String baseId = 'notes'}) =>
    (baseId: baseId, path: path(name));

void main() {
  group('conflictWaitsIn', () {
    test('a listed conflict of the document waits', () {
      expect(conflictWaitsIn(_listed(['todo.md']), _key('todo.md')), isTrue);
    });

    test('no conflict of the document waits when none is listed for it', () {
      expect(conflictWaitsIn(_listed(['other.md']), _key('todo.md')), isFalse);
    });

    test('nothing waits in a base that is not listed', () {
      final state = FolderState({'notes': const NotListed()});
      expect(conflictWaitsIn(state, _key('todo.md')), isFalse);
    });

    test('nothing waits in an unknown base', () {
      expect(
        conflictWaitsIn(_listed(['todo.md']), _key('todo.md', baseId: 'work')),
        isFalse,
      );
    });
  });
}
