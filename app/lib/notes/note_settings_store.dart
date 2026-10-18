import 'dart:io';

import 'package:truce_core/truce_core.dart';

import '../storage/json_file.dart';
import 'checked_items.dart';
import 'note.dart';
import 'note_settings.dart';
import 'note_view.dart';

/// Keeps the [NoteSettings] of each note in a JSON file in app storage. Per
/// device and never synced. A convenience: read and write failures are
/// ignored.
///
/// ```json
/// {"f1/todo.md": {"view": "list", "pinned": true, "checked": "toEnd"}}
/// ```
///
/// Older app versions kept only the view, as a string (`"f1/a.md": "list"`);
/// those still read, as do entries with `"doneSection": true` or `false`
/// instead of `checked`.
final class NoteSettingsStore {
  NoteSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved settings by [storeKey]; empty if none or unreadable. Skips
  /// entries it cannot read.
  Future<Map<String, NoteSettings>> load() async => switch (await _file
      .read()) {
    Ok(value: final Map<String, Object?> json) => {
      for (final MapEntry(:key, :value) in json.entries) key: ?_decode(value),
    },
    _ => const {},
  };

  /// Replaces the saved settings; on failure the next save tries again.
  Future<void> save(Map<String, NoteSettings> settings) => _file.write({
    for (final MapEntry(:key, :value) in settings.entries) key: _encode(value),
  });

  /// Key of [note] in the saved map.
  static String storeKey(NoteKey note) =>
      '${folderPrefix(note.folderId)}${note.path.value}';

  /// How the keys of the notes in folder [folderId] start.
  static String folderPrefix(String folderId) => '$folderId/';

  static Map<String, Object?> _encode(NoteSettings settings) => {
    if (settings.view case final view?) 'view': view.name,
    'pinned': settings.pinned,
    'checked': settings.checkedItems.name,
  };

  static NoteSettings? _decode(Object? json) => switch (json) {
    final String view => switch (_view(view)) {
      final view? => NoteSettings(view: view),
      null => null,
    },
    {'pinned': final bool pinned} => switch (_checkedItems(json)) {
      final checkedItems? => NoteSettings(
        view: _view(json['view']),
        pinned: pinned,
        checkedItems: checkedItems,
      ),
      null => null,
    },
    _ => null,
  };

  static CheckedItems? _checkedItems(Map<Object?, Object?> json) =>
      switch (json) {
        {'checked': final Object name} => CheckedItems.values.asNameMap()[name],
        {'doneSection': final bool on} =>
          on ? CheckedItems.doneSection : CheckedItems.inPlace,
        _ => null,
      };

  static NoteView? _view(Object? name) => NoteView.values.asNameMap()[name];
}
