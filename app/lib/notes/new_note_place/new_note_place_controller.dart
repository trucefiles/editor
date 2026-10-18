import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../../storage/app_storage.dart';
import 'new_note_place.dart';
import 'new_note_place_store.dart';

final newNotePlaceStoreProvider = Provider<NewNotePlaceStore>(
  (ref) => NewNotePlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/new_note_place.json'),
  ),
);

final newNotePlaceProvider =
    AsyncNotifierProvider<NewNotePlaceController, NewNotePlaceSetting?>(
      NewNotePlaceController.new,
    );

/// The setting of where new notes go on this device; `null` for the
/// default (see `NoteActions.defaultFolder`).
class NewNotePlaceController extends AsyncNotifier<NewNotePlaceSetting?> {
  final _changes = Pool(1);

  @override
  Future<NewNotePlaceSetting?> build() =>
      ref.watch(newNotePlaceStoreProvider).load();

  /// Takes [place] once the setting is loaded, so screens show it; saves
  /// it after every earlier change.
  Future<void> set(NewNotePlaceSetting? place) async {
    await future;
    state = AsyncData(place);
    await _changes.withResource(
      () => ref.read(newNotePlaceStoreProvider).save(place),
    );
  }
}
