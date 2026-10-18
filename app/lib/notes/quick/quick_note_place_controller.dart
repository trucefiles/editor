import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../../storage/app_storage.dart';
import 'quick_note_place.dart';
import 'quick_note_place_store.dart';

final quickNotePlaceStoreProvider = Provider<QuickNotePlaceStore>(
  (ref) => QuickNotePlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/quick_note.json'),
  ),
);

final quickNotePlaceProvider =
    AsyncNotifierProvider<QuickNotePlaceController, QuickNotePlace?>(
      QuickNotePlaceController.new,
    );

/// The setting of where quick notes go on this device; `null` for the
/// default (see `NoteActions.defaultFolder`).
class QuickNotePlaceController extends AsyncNotifier<QuickNotePlace?> {
  final _changes = Pool(1);

  @override
  Future<QuickNotePlace?> build() =>
      ref.watch(quickNotePlaceStoreProvider).load();

  /// Takes [place] once the setting is loaded, so screens show it; saves
  /// it after every earlier change.
  Future<void> set(QuickNotePlace? place) async {
    await future;
    state = AsyncData(place);
    await _changes.withResource(
      () => ref.read(quickNotePlaceStoreProvider).save(place),
    );
  }
}
