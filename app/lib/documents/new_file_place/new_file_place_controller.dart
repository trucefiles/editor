import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/setting_controller.dart';
import '../../storage/app_storage.dart';
import 'new_file_place.dart';
import 'new_file_place_store.dart';

final newFilePlaceStoreProvider = Provider<SettingStore<NewFilePlaceSetting?>>(
  (ref) => NewFilePlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/new_file_place.json'),
  ),
);

final newFilePlaceProvider =
    AsyncNotifierProvider<NewFilePlaceController, NewFilePlaceSetting?>(
      NewFilePlaceController.new,
    );

/// The setting of where new documents go on this device; `null` for the
/// default (see `DocumentActions.defaultFolder`).
class NewFilePlaceController extends SettingController<NewFilePlaceSetting?> {
  @override
  Provider<SettingStore<NewFilePlaceSetting?>> get store =>
      newFilePlaceStoreProvider;
}
