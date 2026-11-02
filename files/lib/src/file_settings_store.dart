import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'file_settings.dart';
import 'kept_file_settings.dart';
import 'listed_file.dart';
import 'view_settings.dart';

/// Keeps the [KeptFileSettings] of each file in a JSON file in app storage,
/// keyed by folder and path. Per device and never synced. A
/// convenience: read and write failures are ignored. `view` is the
/// file type's own part, kept as is.
///
/// ```json
/// {"syncthing-f1/todo.md": {"pinned": true,
///                           "view": {"mode": "visual"}},
///  "syncthing-f1/old.md": {"pinned": true, "view": {},
///                          "missingSince": "2026-10-21T09:00:00.000Z"}}
/// ```
final class FileSettingsStore
    implements SettingStore<Map<String, KeptFileSettings>> {
  FileSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved settings by [storeKey]; empty if none or unreadable. Skips
  /// entries it cannot read.
  @override
  Future<Map<String, KeptFileSettings>> load() async => switch (await _file
      .read()) {
    Ok(value: final Map<String, Object?> json) => {
      for (final MapEntry(:key, :value) in json.entries)
        if (_decode(value) case final settings?)
          key: KeptFileSettings(settings, missingSince: _missingSince(value)),
    },
    _ => const {},
  };

  /// Replaces the saved settings; on failure the next save tries again.
  @override
  Future<void> save(Map<String, KeptFileSettings> settings) => _file.write({
    for (final MapEntry(:key, :value) in settings.entries) key: _encode(value),
  });

  /// Key of [file] in the saved map.
  static String storeKey(FileKey file) =>
      '${file.folder.storageName}/${file.path.value}';

  /// The file [storeKey] names; `null` if it names none.
  static FileKey? keyOf(String storeKey) {
    final slash = storeKey.indexOf('/');
    final dash = storeKey.indexOf('-');
    if (slash < 0 || dash < 0 || dash > slash) return null;
    return switch (RelPath.parse(storeKey.substring(slash + 1))) {
      final path? => (
        folder: FolderId(
          storeKey.substring(0, dash),
          storeKey.substring(dash + 1, slash),
        ),
        path: path,
      ),
      null => null,
    };
  }

  static Map<String, Object?> _encode(KeptFileSettings kept) => {
    'pinned': kept.settings.pinned,
    'view': kept.settings.view.json,
    if (kept.missingSince case final since?)
      'missingSince': since.toUtc().toIso8601String(),
  };

  static DateTime? _missingSince(Object? json) => switch (json) {
    {'missingSince': final String since} => DateTime.tryParse(since),
    _ => null,
  };

  /// A `view` it can't read (or none, as saved before types kept their
  /// own) is as never chosen.
  static FileSettings? _decode(Object? json) => switch (json) {
    {'pinned': final bool pinned, 'view': final Map<String, Object?> view} =>
      FileSettings(pinned: pinned, view: ViewSettings(view)),
    {'pinned': final bool pinned} => FileSettings(pinned: pinned),
    _ => null,
  };
}
