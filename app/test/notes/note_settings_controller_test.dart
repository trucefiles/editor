import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/kept_note_settings.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_settings.dart';
import 'package:truce_editor/notes/note_settings_controller.dart';
import 'package:truce_editor/notes/note_settings_store.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

import '../support.dart';

void main() {
  late ProviderContainer container;
  late NoteSettingsController views;
  final a = (folderId: 'f1', path: path('a.md'));
  final b = (folderId: 'f1', path: path('b.md'));

  setUp(() {
    final storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    views = container.read(noteSettingsProvider.notifier);
  });

  Future<Map<String, NoteSettings>> saved() async => {
    for (final MapEntry(:key, :value)
        in (await container.read(noteSettingsStoreProvider).load()).entries)
      key: value.settings,
  };

  Future<void> remember(NoteKey note, EditMode view) =>
      views.edit(note, (settings) => settings.withMode(view));

  EditMode? viewOf(NoteKey note) => views.settingsOf(note).mode;

  test('views remembered at the same time are all kept', () async {
    await Future.wait([
      remember(a, EditMode.markdown),
      remember(b, EditMode.read),
    ]);

    final expected = {
      NoteSettingsStore.storeKey(a): NoteSettings(mode: EditMode.markdown),
      NoteSettingsStore.storeKey(b): NoteSettings(mode: EditMode.read),
    };
    expect(
      container.read(noteSettingsProvider).value,
      expected.map((key, value) => MapEntry(key, KeptNoteSettings(value))),
    );
    expect(await saved(), expected);
  });

  test('forget drops the view of a note', () async {
    await remember(a, EditMode.markdown);
    await remember(b, EditMode.read);

    await views.forget(a);

    expect(viewOf(a), isNull);
    expect(await saved(), {
      NoteSettingsStore.storeKey(b): NoteSettings(mode: EditMode.read),
    });
  });

  test('keeps pin and checked items with the view', () async {
    await remember(a, EditMode.visual);
    await views.edit(a, (settings) => settings.withPinned(pinned: true));
    await views.edit(
      a,
      (settings) => settings.withCheckedItems(CheckedItems.moveToEnd),
    );

    const expected = NoteSettings(
      mode: EditMode.visual,
      pinned: true,
      checkedItems: CheckedItems.moveToEnd,
    );
    expect(views.settingsOf(a), expected);
    expect(await saved(), {NoteSettingsStore.storeKey(a): expected});
  });

  test('drops settings changed back to the defaults', () async {
    await views.edit(a, (settings) => settings.withPinned(pinned: true));

    await views.edit(a, (settings) => settings.withPinned(pinned: false));

    expect(views.settingsOf(a), NoteSettings.defaults);
    expect(await saved(), isEmpty);
  });

  group('prune', () {
    late NoteFolder work;
    late NoteFolder home;

    setUp(() {
      work = folderAt(tempFolder(), id: 'work');
      home = folderAt(tempFolder(), id: 'home');
    });

    final now = DateTime.utc(2026, 10, 21, 9);
    final graceLater = now.add(KeptNoteSettings.grace);

    Note noteAt(NoteFolder folder, String name) =>
        noteOf(folder, '', name: name);

    /// Prunes by [found] now and again once the grace period is over.
    Future<void> pruneAfterGrace(FolderScans found) async {
      await views.prune(found, now: now);
      await views.prune(found, now: graceLater);
    }

    FolderScans scans(
      List<Note> notes, {
      Map<NoteFolder, StoreError> failed = const {},
      Map<String, List<RelPath>> unreadable = const {},
      Set<NoteKey> unreadNotes = const {},
    }) => FolderScans(
      notes: notes,
      marks: const {},
      subfolders: const {},
      conflicts: FolderConflicts(const []),
      failedFolders: failed,
      unreadable: unreadable,
      startedAt: Moment.now(),
      unreadNotes: unreadNotes,
    );

    test('drops views of notes and folders that are gone', () async {
      final kept = noteAt(work, 'kept.md');
      await remember(kept.key, EditMode.visual);
      await remember(noteAt(work, 'gone.md').key, EditMode.markdown);
      await remember((
        folderId: 'removed',
        path: path('a.md'),
      ), EditMode.markdown);

      await pruneAfterGrace(scans([kept]));

      expect(await saved(), {
        NoteSettingsStore.storeKey(kept.key): NoteSettings(
          mode: EditMode.visual,
        ),
      });
    });

    test('keeps the settings of a missing note for a while', () async {
      final gone = noteAt(work, 'gone.md');
      await views.edit(gone.key, (s) => s.withPinned(pinned: true));

      await views.prune(scans([]), now: now);
      await views.prune(
        scans([]),
        now: graceLater.subtract(const Duration(minutes: 1)),
      );

      expect(views.settingsOf(gone.key).pinned, isTrue);
    });

    test('a note found again starts its grace period anew', () async {
      final back = noteAt(work, 'back.md');
      await views.edit(back.key, (s) => s.withPinned(pinned: true));

      await views.prune(scans([]), now: now);
      await views.prune(scans([back]), now: now.add(const Duration(days: 1)));
      await views.prune(scans([]), now: now.add(const Duration(days: 2)));
      await views.prune(scans([]), now: graceLater);

      expect(views.settingsOf(back.key).pinned, isTrue);
    });

    test('keeps the time a note went missing across restarts', () async {
      final gone = noteAt(work, 'gone.md');
      await views.edit(gone.key, (s) => s.withPinned(pinned: true));
      await views.prune(scans([]), now: now);

      container.invalidate(noteSettingsProvider);
      views = container.read(noteSettingsProvider.notifier);
      await views.prune(scans([]), now: graceLater);

      expect(views.settingsOf(gone.key).pinned, isFalse);
    });

    test('keeps views of folders that could not be scanned', () async {
      final unread = noteAt(home, 'a.md');
      await remember(unread.key, EditMode.read);

      await pruneAfterGrace(scans([], failed: {home: StoreError.ioFailure}));

      expect(viewOf(unread.key), EditMode.read);
    });

    test('keeps views below subfolders that could not be read', () async {
      final hidden = noteAt(work, 'private/a.md');
      final gone = noteAt(work, 'privateer.md');
      await remember(hidden.key, EditMode.read);
      await remember(gone.key, EditMode.markdown);

      await pruneAfterGrace(
        scans(
          [],
          unreadable: {
            work.id: [path('private')],
          },
        ),
      );

      expect(viewOf(hidden.key), EditMode.read);
      expect(viewOf(gone.key), isNull);
    });

    test('keeps views of notes whose files could not be read', () async {
      final unread = noteAt(work, 'a.md');
      await remember(unread.key, EditMode.read);

      await pruneAfterGrace(scans([], unreadNotes: {unread.key}));

      expect(viewOf(unread.key), EditMode.read);
    });
  });
}
