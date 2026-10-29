import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'document.dart';
import 'document_settings.dart';
import 'kept_document_settings.dart';
import 'view_settings.dart';

/// Keeps the [KeptDocumentSettings] of each document in a JSON file in app storage,
/// keyed by base folder id and path. Per device and never synced. A
/// convenience: read and write failures are ignored. `view` is the
/// document type's own part, kept as is.
///
/// ```json
/// {"b1/todo.md": {"pinned": true,
///                 "view": {"mode": "visual", "checked": "moveToEnd"}},
///  "b1/old.md": {"pinned": true, "view": {},
///                "missingSince": "2026-10-21T09:00:00.000Z"}}
/// ```
final class DocumentSettingsStore
    implements SettingStore<Map<String, KeptDocumentSettings>> {
  DocumentSettingsStore(File file) : _file = JsonFile(file);

  final JsonFile _file;

  /// The saved settings by [storeKey]; empty if none or unreadable. Skips
  /// entries it cannot read.
  @override
  Future<Map<String, KeptDocumentSettings>> load() async =>
      switch (await _file.read()) {
        Ok(value: final Map<String, Object?> json) => {
          for (final MapEntry(:key, :value) in json.entries)
            if (_decode(value) case final settings?)
              key: KeptDocumentSettings(
                settings,
                missingSince: _missingSince(value),
              ),
        },
        _ => const {},
      };

  /// Replaces the saved settings; on failure the next save tries again.
  @override
  Future<void> save(Map<String, KeptDocumentSettings> settings) => _file.write({
    for (final MapEntry(:key, :value) in settings.entries) key: _encode(value),
  });

  /// Key of [document] in the saved map.
  static String storeKey(DocumentKey document) =>
      '${document.baseId}/${document.path.value}';

  /// The document [storeKey] names; `null` if it names none.
  static DocumentKey? keyOf(String storeKey) {
    final at = storeKey.indexOf('/');
    if (at < 0) return null;
    return switch (RelPath.parse(storeKey.substring(at + 1))) {
      final path? => (baseId: storeKey.substring(0, at), path: path),
      null => null,
    };
  }

  static Map<String, Object?> _encode(KeptDocumentSettings kept) => {
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
  static DocumentSettings? _decode(Object? json) => switch (json) {
    {'pinned': final bool pinned, 'view': final Map<String, Object?> view} =>
      DocumentSettings(pinned: pinned, view: ViewSettings(view)),
    {'pinned': final bool pinned} => DocumentSettings(pinned: pinned),
    _ => null,
  };
}
