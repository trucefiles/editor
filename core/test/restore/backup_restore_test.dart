import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import '../support/memory_file_store.dart';
import '../support/test_helpers.dart';

void main() {
  final at = DateTime.utc(2026, 10, 12, 15);
  final later = at.add(const Duration(hours: 1));

  late MemoryFileStore folder;
  late MemoryFileStore backupStore;
  late NoteBackups backups;
  late BackupRestore restore;

  setUp(() async {
    folder = MemoryFileStore();
    backupStore = MemoryFileStore();
    backups = NoteBackups(backupStore);
    restore = BackupRestore(
      folder: folder,
      backups: backups,
      clock: () => later,
    );
    await backups.saveBeforeEdit(
      at: at,
      notePath: path('todo.md'),
      bytes: bytesOf('backup'),
    );
  });

  Future<RestoreChoice> load() async =>
      (await restore.load((await backups.list()).value.single)).value;

  /// The texts of the backups saved when keeping a version.
  Set<String> keptBackups() => {
    for (final MapEntry(:key, :value) in backupStore.files.entries)
      if (Backup.parse(key)!.savedAt == later)
        String.fromCharCodes(value.bytes),
  };

  test('loads the backup next to the note', () async {
    folder.put('todo.md', 'now');

    final choice = await load();

    expect(String.fromCharCodes(choice.bytes), 'backup');
    expect(String.fromCharCodes(choice.current!.bytes), 'now');
  });

  test('restores the backup over the note, after a backup of both', () async {
    folder.put('todo.md', 'now');

    final kept = await restore.keep(await load(), const KeepOther());

    expect(kept, isA<Ok<void, ResolveError>>());
    expect(folder.textOf('todo.md'), 'backup');
    expect(keptBackups(), {'now', 'backup'});
  });

  test('restores a deleted note', () async {
    final choice = await load();
    expect(choice.current, isNull);

    await restore.keep(choice, const KeepOther());

    expect(folder.textOf('todo.md'), 'backup');
    expect(keptBackups(), {'backup'});
  });

  test('keeping the note writes nothing to it', () async {
    folder.put('todo.md', 'now');

    await restore.keep(await load(), const KeepCurrent());

    expect(folder.textOf('todo.md'), 'now');
    expect(keptBackups(), {'now', 'backup'});
  });

  test('never overwrites a change made after loading', () async {
    folder.put('todo.md', 'now');
    final choice = await load();
    folder.put('todo.md', 'changed');

    final kept = await restore.keep(choice, const KeepOther());

    expect(kept.error, ResolveError.changedSinceScan);
    expect(folder.textOf('todo.md'), 'changed');
  });

  test('never overwrites a note recreated after loading', () async {
    final choice = await load();
    folder.put('todo.md', 'new');

    final kept = await restore.keep(choice, const KeepOther());

    expect(kept.error, ResolveError.changedSinceScan);
    expect(folder.textOf('todo.md'), 'new');
  });

  test('changes nothing if no backup can be made', () async {
    folder.put('todo.md', 'now');
    final choice = await load();
    backupStore.failWith = StoreError.ioFailure;

    final kept = await restore.keep(choice, const KeepOther());

    expect(kept.error, ResolveError.backupFailed);
    expect(folder.textOf('todo.md'), 'now');
  });
}
