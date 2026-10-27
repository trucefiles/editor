import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/setting_controller.dart';
import '../../storage/app_storage.dart';
import 'new_document_place.dart';
import 'new_document_place_store.dart';

final newNotePlaceStoreProvider = Provider<SettingStore<NewNotePlaceSetting?>>(
  (ref) => NewNotePlaceStore(
    File('${ref.watch(appStorageProvider).settingsPath}/new_note_place.json'),
  ),
);

final newNotePlaceProvider =
    AsyncNotifierProvider<NewNotePlaceController, NewNotePlaceSetting?>(
      NewNotePlaceController.new,
    );

/// The setting of where new documents go on this device; `null` for the
/// default (see `DocumentActions.defaultFolder`).
class NewNotePlaceController extends SettingController<NewNotePlaceSetting?> {
  @override
  Provider<SettingStore<NewNotePlaceSetting?>> get store =>
      newNotePlaceStoreProvider;
}
