import 'package:test/test.dart';
import 'package:truce_core/testing.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

void main() {
  const adapter = SyncthingAdapter();

  group('isInternal', () {
    test("matches Syncthing's files and folders at any depth", () {
      for (final raw in [
        '.stfolder',
        '.stignore',
        '.stversions/notes/todo.md',
        'notes/.stfolder',
        '.syncthing.todo.md.tmp',
        'notes/.syncthing.truce-1a2b.tmp',
        '~syncthing~todo.md.tmp',
        'notes/todo.sync-conflict-20261003-134809-4I343AW.md',
      ]) {
        expect(adapter.isInternal(path(raw)), isTrue, reason: raw);
      }
    });

    test('does not match notes or other dotfiles', () {
      for (final raw in [
        'todo.md',
        'notes/todo.md',
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
        ['sync', '.stversions', 'Notes'],
        ['sync', '.stfolder'],
      ]) {
        expect(adapter.isInternalFolder(names), isTrue, reason: '$names');
      }
    });

    test('does not match note folders', () {
      for (final names in [
        <String>[],
        ['sync', 'Notes'],
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
