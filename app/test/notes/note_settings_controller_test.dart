import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_settings.dart';
import 'package:truce_editor/notes/note_settings_controller.dart';
import 'package:truce_editor/notes/note_settings_store.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/storage/app_storage.dart';

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

  Future<Map<String, NoteSettings>> saved() =>
      container.read(noteSettingsStoreProvider).load();

  Future<void> remember(NoteKey note, NoteView view) =>
      views.edit(note, (settings) => settings.withView(view));

  NoteView? viewOf(NoteKey note) => views.settingsOf(note).view;

  test('views remembered at the same time are all kept', () async {
    await Future.wait([
      remember(a, NoteView.text),
      remember(b, NoteView.rendered),
    ]);

    final expected = {
      NoteSettingsStore.storeKey(a): NoteSettings(view: NoteView.text),
      NoteSettingsStore.storeKey(b): NoteSettings(view: NoteView.rendered),
    };
    expect(container.read(noteSettingsProvider).value, expected);
    expect(await saved(), expected);
  });

  test('forget drops the view of a note', () async {
    await remember(a, NoteView.text);
    await remember(b, NoteView.rendered);

    await views.forget(a);

    expect(viewOf(a), isNull);
    expect(await saved(), {
      NoteSettingsStore.storeKey(b): NoteSettings(view: NoteView.rendered),
    });
  });

  test('keeps pin, Done section and checked order with the view', () async {
    await remember(a, NoteView.list);
    await views.edit(a, (settings) => settings.withPinned(pinned: true));
    await views.edit(
      a,
      (settings) => settings.withDoneSection(doneSection: false),
    );
    await views.edit(
      a,
      (settings) => settings.withCheckedToEnd(checkedToEnd: true),
    );

    const expected = NoteSettings(
      view: NoteView.list,
      pinned: true,
      doneSection: false,
      checkedToEnd: true,
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

    Note noteAt(NoteFolder folder, String name) => Note(
      folder: folder,
      path: path(name),
      file: const TextFile.empty(),
      version: const FileVersion(0),
      modified: DateTime(2000),
    );

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
      await remember(kept.key, NoteView.list);
      await remember(noteAt(work, 'gone.md').key, NoteView.text);
      await remember((folderId: 'removed', path: path('a.md')), NoteView.text);

      await views.prune(scans([kept]));

      expect(await saved(), {
        NoteSettingsStore.storeKey(kept.key): NoteSettings(view: NoteView.list),
      });
    });

    test('keeps views of folders that could not be scanned', () async {
      final unread = noteAt(home, 'a.md');
      await remember(unread.key, NoteView.rendered);

      await views.prune(scans([], failed: {home: StoreError.ioFailure}));

      expect(viewOf(unread.key), NoteView.rendered);
    });

    test('keeps views below subfolders that could not be read', () async {
      final hidden = noteAt(work, 'private/a.md');
      final gone = noteAt(work, 'privateer.md');
      await remember(hidden.key, NoteView.rendered);
      await remember(gone.key, NoteView.text);

      await views.prune(
        scans(
          [],
          unreadable: {
            work.id: [path('private')],
          },
        ),
      );

      expect(viewOf(hidden.key), NoteView.rendered);
      expect(viewOf(gone.key), isNull);
    });

    test('keeps views of notes whose files could not be read', () async {
      final unread = noteAt(work, 'a.md');
      await remember(unread.key, NoteView.rendered);

      await views.prune(scans([], unreadNotes: {unread.key}));

      expect(viewOf(unread.key), NoteView.rendered);
    });
  });
}
