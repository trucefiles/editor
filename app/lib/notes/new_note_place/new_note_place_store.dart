import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../../storage/json_file.dart';
import 'new_note_place.dart';

/// Keeps the [NewNotePlaceSetting] setting in a JSON file in app storage. A
/// convenience: read and write failures are ignored.
///
/// ```json
/// {"folder": "f1", "subfolder": "inbox"}
/// ```
final class NewNotePlaceStore {
  NewNotePlaceStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved place; `null` if none, or unreadable.
  Future<NewNotePlaceSetting?> load() async => switch (await _file.read()) {
    Ok(value: final json) => decode(json),
    _ => null,
  };

  /// Saves [place]; `null` saves that none is chosen.
  Future<void> save(NewNotePlaceSetting? place) => _file.write(encode(place));

  static Object? encode(NewNotePlaceSetting? place) => switch (place) {
    (:final folderId, :final subfolder) => {
      'folder': folderId,
      if (subfolder != null) 'subfolder': subfolder.value,
    },
    null => null,
  };

  /// `null` if [json] holds no place written by [encode].
  static NewNotePlaceSetting? decode(Object? json) => switch (json) {
    {'folder': final String folderId, 'subfolder': final String raw} =>
      switch (RelPath.parse(raw)) {
        final subfolder? => (folderId: folderId, subfolder: subfolder),
        null => null,
      },
    {'folder': final String folderId} => (folderId: folderId, subfolder: null),
    _ => null,
  };
}
