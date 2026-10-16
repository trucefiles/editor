import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

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

  /// Runs after every earlier [remember], so each starts from the views
  /// the one before saved.
  Future<void> remember(NoteKey note, NoteView view) =>
      _changes.withResource(() async {
        final views = {...await future, NoteViewStore.storeKey(note): view};
        state = AsyncData(views);
        await ref.read(noteViewStoreProvider).save(views);
      });
}
