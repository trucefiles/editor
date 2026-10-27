import 'dart:io';

import 'package:truce_core/truce_core.dart' show Ok;

import '../../storage/json_file.dart';
import '../../storage/setting_store.dart';
import 'add_item_place.dart';

/// Keeps where a list's add buttons sit in a JSON file in app storage. Per
/// device. At the top unless the user chose the bottom; read and write
/// failures fall back to that.
final class AddItemPlaceStore implements SettingStore<AddItemPlace> {
  AddItemPlaceStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  static const _key = 'addItems';

  /// The saved place; [AddItemPlace.top] if none or unreadable.
  @override
  Future<AddItemPlace> load() async => switch (await _file.read()) {
    Ok(value: {_key: 'bottom'}) => AddItemPlace.bottom,
    _ => AddItemPlace.top,
  };

  /// Replaces the saved place; on failure it stays as it is for this run.
  @override
  Future<void> save(AddItemPlace place) => _file.write({_key: place.name});
}
