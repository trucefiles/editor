import 'package:test/test.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const adapter = SyncthingRules();

  group('isInternal', () {
    test("matches Syncthing's files and folders at any depth", () {
      for (final raw in [
        '.stfolder',
        '.stignore',
        '.stversions/documents/todo.md',
        'documents/.stfolder',
        '.syncthing.todo.md.tmp',
        'documents/.syncthing.truce-1a2b.tmp',
        '~syncthing~todo.md.tmp',
        'documents/todo.sync-conflict-20261003-134809-4I343AW.md',
      ]) {
        expect(adapter.isInternal(path(raw)), isTrue, reason: raw);
      }
    });

    test('does not match documents or other dotfiles', () {
      for (final raw in [
        'todo.md',
        'documents/todo.md',
        '.hidden',
        '.syncthing.todo.md',
        'stversions/todo.md',
      ]) {
        expect(adapter.isInternal(path(raw)), isFalse, reason: raw);
      }
    });
  });

  group('isInternalFolder', () {
    test("matches Syncthing's folders and anything inside them", () {
      for (final names in [
        ['sync', '.stversions'],
        ['sync', '.stversions', 'Documents'],
        ['sync', '.stfolder'],
      ]) {
        expect(adapter.isInternalFolder(names), isTrue, reason: '$names');
      }
    });

    test('does not match document folders', () {
      for (final names in [
        <String>[],
        ['sync', 'Documents'],
        ['sync', 'stversions'],
        ['sync', '.hidden'],
      ]) {
        expect(adapter.isInternalFolder(names), isFalse, reason: '$names');
      }
    });
  });

  test('temp files are Syncthing temp files', () {
    final name = adapter.tempFileName('1a2b');

    expect(name, '.syncthing.truce-1a2b.tmp');
    expect(adapter.isInternal(path(name)), isTrue);
  });
}
