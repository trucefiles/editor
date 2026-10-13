import 'dart:convert';
import 'dart:typed_data';

import '../storage/rel_path.dart';
import 'note_mark.dart';

/// A [NoteMark] with the time it was set, so the newest wins across devices.
typedef StampedMark = ({NoteMark mark, DateTime changed});

/// The JSON file of one device's marks, by note path:
///
/// ```json
/// {
///   "lists/todo.md": {
///     "pinned": true,
///     "color": "teal",
///     "changed": "2026-10-13T18:40:00.000Z"
///   }
/// }
/// ```
///
/// Keeps unmarked notes too (`"pinned": false, "color": null`), so an unpin
/// beats an older pin from another device.
abstract final class NoteMarksFile {
  /// The marks in [bytes]. Skips entries it cannot read; empty if the whole
  /// file is unreadable.
  static Map<RelPath, StampedMark> decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return {};
    }
    if (json is! Map<String, Object?>) return {};
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if ((RelPath.parse(key), _decodeEntry(value)) case (
          final path?,
          final stamped?,
        ))
          path: stamped,
    };
  }

  /// [marks] as JSON, sorted by path so diffs stay small.
  static Uint8List encode(Map<RelPath, StampedMark> marks) {
    final paths = marks.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final json = {
      for (final path in paths) path.value: _encodeEntry(marks[path]!),
    };
    return utf8.encode('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }

  static Map<String, Object?> _encodeEntry(StampedMark stamped) => {
    'pinned': stamped.mark.pinned,
    'color': stamped.mark.color,
    'changed': stamped.changed.toUtc().toIso8601String(),
  };

  static StampedMark? _decodeEntry(Object? json) => switch (json) {
    {
      'pinned': final bool pinned,
      'color': final String? color,
      'changed': final String changed,
    } =>
      switch (DateTime.tryParse(changed)) {
        final time? => (
          mark: NoteMark(pinned: pinned, color: color),
          changed: time,
        ),
        null => null,
      },
    _ => null,
  };
}
