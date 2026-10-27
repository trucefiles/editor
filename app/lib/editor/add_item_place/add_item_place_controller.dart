import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/setting_controller.dart';
import '../../storage/app_storage.dart';
import 'add_item_place.dart';
import 'add_item_place_store.dart';

final addItemPlaceStoreProvider = Provider<SettingStore<AddItemPlace>>(
  (ref) => AddItemPlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/add_items.json'),
  ),
);

final addItemPlaceProvider =
    AsyncNotifierProvider<AddItemPlaceController, AddItemPlace>(
      AddItemPlaceController.new,
    );

/// The setting of where a list's add buttons sit on this device.
class AddItemPlaceController extends SettingController<AddItemPlace> {
  @override
  Provider<SettingStore<AddItemPlace>> get store => addItemPlaceStoreProvider;
}
