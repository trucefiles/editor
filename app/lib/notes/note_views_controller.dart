import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../scan/folder_scans.dart';
import '../storage/app_storage.dart';
import 'note.dart';
import 'note_view.dart';
import 'note_view_store.dart';

final noteViewStoreProvider = Provider<NoteViewStore>(
  (ref) => NoteViewStore(
    File('${ref.watch(appStorageProvider).settingsPath}/note_views.json'),
  ),
);

final noteViewsProvider =
    AsyncNotifierProvider<NoteViewsController, Map<String, NoteView>>(
      NoteViewsController.new,
    );

/// The view each note was last shown in on this device.
class NoteViewsController extends AsyncNotifier<Map<String, NoteView>> {
  final _changes = Pool(1);

  @override
  Future<Map<String, NoteView>> build() =>
      ref.watch(noteViewStoreProvider).load();

  /// The last view of [note]; `null` if unknown or not loaded yet.
  NoteView? viewOf(NoteKey note) => state.value?[NoteViewStore.storeKey(note)];

  /// Runs after every earlier change, so each starts from the views the
  /// one before saved.
  Future<void> remember(NoteKey note, NoteView view) =>
      _change((views) => views[NoteViewStore.storeKey(note)] = view);

  /// Forgets the view of [note], e.g. as the user deletes it. As
  /// [remember].
  Future<void> forget(NoteKey note) =>
      _change((views) => views.remove(NoteViewStore.storeKey(note)));

  /// Forgets the views of notes that [scans] did not find in folders that
  /// were scanned, and of folders that are gone. Keeps those of folders
  /// that could not be scanned. As [remember].
  Future<void> prune(FolderScans scans) {
    final found = {
      for (final note in scans.notes) NoteViewStore.storeKey(note.key),
    };
    final unknown = [
      for (final folder in scans.failedFolders.keys)
        NoteViewStore.folderPrefix(folder.id),
    ];
    return _change(
      (views) => views.removeWhere(
        (key, _) => !found.contains(key) && !unknown.any(key.startsWith),
      ),
    );
  }

  /// Applies [apply] to the views; saves them if it changed any.
  Future<void> _change(void Function(Map<String, NoteView> views) apply) =>
      _changes.withResource(() async {
        final before = await future;
        final views = {...before};
        apply(views);
        if (mapEquals(before, views)) return;
        state = AsyncData(views);
        await ref.read(noteViewStoreProvider).save(views);
      });
}
