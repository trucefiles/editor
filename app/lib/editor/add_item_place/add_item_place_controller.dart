import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';
import 'package:truce_core/truce_core.dart';

import '../../storage/app_storage.dart';
import 'add_item_place_store.dart';

final addItemPlaceStoreProvider = Provider<AddItemPlaceStore>(
  (ref) => AddItemPlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/add_items.json'),
  ),
);

final addItemPlaceProvider =
    AsyncNotifierProvider<AddItemPlaceController, AddItemPlace>(
      AddItemPlaceController.new,
    );

/// The setting of where a list's add buttons sit on this device.
class AddItemPlaceController extends AsyncNotifier<AddItemPlace> {
  final _changes = Pool(1);

  @override
  Future<AddItemPlace> build() => ref.watch(addItemPlaceStoreProvider).load();

  /// Takes [place] once the setting is loaded, so screens show it; saves
  /// it after every earlier change.
  Future<void> set(AddItemPlace place) async {
    await future;
    state = AsyncData(place);
    await _changes.withResource(
      () => ref.read(addItemPlaceStoreProvider).save(place),
    );
  }
}
