import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/notes/note_view_store.dart';
import 'package:truce_editor/notes/note_views_controller.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  late ProviderContainer container;
  late NoteViewsController views;
  final a = (folderId: 'f1', path: path('a.md'));
  final b = (folderId: 'f1', path: path('b.md'));

  setUp(() {
    final storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    views = container.read(noteViewsProvider.notifier);
  });

  Future<Map<String, NoteView>> saved() =>
      container.read(noteViewStoreProvider).load();

  test('views remembered at the same time are all kept', () async {
    await Future.wait([
      views.remember(a, NoteView.text),
      views.remember(b, NoteView.rendered),
    ]);

    final expected = {
      NoteViewStore.storeKey(a): NoteView.text,
      NoteViewStore.storeKey(b): NoteView.rendered,
    };
    expect(container.read(noteViewsProvider).value, expected);
    expect(await saved(), expected);
  });

  test('forget drops the view of a note', () async {
    await views.remember(a, NoteView.text);
    await views.remember(b, NoteView.rendered);

    await views.forget(a);

    expect(views.viewOf(a), isNull);
    expect(await saved(), {NoteViewStore.storeKey(b): NoteView.rendered});
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
    }) => FolderScans(
      notes: notes,
      marks: const {},
      subfolders: const {},
      conflicts: FolderConflicts(const []),
      failedFolders: failed,
      unreadable: unreadable,
      startedAt: Moment.now(),
    );

    test('drops views of notes and folders that are gone', () async {
      final kept = noteAt(work, 'kept.md');
      await views.remember(kept.key, NoteView.list);
      await views.remember(noteAt(work, 'gone.md').key, NoteView.text);
      await views.remember((
        folderId: 'removed',
        path: path('a.md'),
      ), NoteView.text);

      await views.prune(scans([kept]));

      expect(await saved(), {NoteViewStore.storeKey(kept.key): NoteView.list});
    });

    test('keeps views of folders that could not be scanned', () async {
      final unread = noteAt(home, 'a.md');
      await views.remember(unread.key, NoteView.rendered);

      await views.prune(scans([], failed: {home: StoreError.ioFailure}));

      expect(views.viewOf(unread.key), NoteView.rendered);
    });

    test('keeps views below subfolders that could not be read', () async {
      final hidden = noteAt(work, 'private/a.md');
      final gone = noteAt(work, 'privateer.md');
      await views.remember(hidden.key, NoteView.rendered);
      await views.remember(gone.key, NoteView.text);

      await views.prune(
        scans(
          [],
          unreadable: {
            work.id: [path('private')],
          },
        ),
      );

      expect(views.viewOf(hidden.key), NoteView.rendered);
      expect(views.viewOf(gone.key), isNull);
    });
  });
}
