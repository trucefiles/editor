import 'dart:convert';
import 'dart:typed_data';

import '../storage/rel_path.dart';
import 'document_mark.dart';

/// A [DocumentMark] with the time it was set, so the newest wins across devices.
typedef StampedMark = ({DocumentMark mark, DateTime changed});

/// The JSON file of one device's marks, by document path:
///
/// ```json
/// {
///   "lists/todo.md": {
///     "color": "teal",
///     "changed": "2026-10-13T18:40:00.000Z"
///   }
/// }
/// ```
///
/// Keeps unmarked documents too (`"color": null`), so taking a color off beats
/// an older color from another device. Other keys, e.g. `pinned` written
/// by older app versions, are ignored.
abstract final class DocumentMarksFile {
  /// The marks in [bytes]. Skips entries it cannot read; `null` if the
  /// whole file is unreadable.
  static Map<RelPath, StampedMark>? decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
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
    'color': stamped.mark.color,
    'changed': stamped.changed.toUtc().toIso8601String(),
  };

  static StampedMark? _decodeEntry(Object? json) => switch (json) {
    {'color': final String? color, 'changed': final String changed} =>
      switch (DateTime.tryParse(changed)) {
        final time? => (mark: DocumentMark(color: color), changed: time),
        null => null,
      },
    _ => null,
  };
}
