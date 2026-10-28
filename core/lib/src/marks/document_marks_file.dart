import 'dart:convert';
import 'dart:typed_data';

import 'document_mark.dart';

/// A [DocumentMark] with the time it was set, so the newest wins across devices.
typedef StampedMark = ({DocumentMark mark, DateTime changed});

/// The JSON file of one device's marks of the documents in one directory,
/// by file name:
///
/// ```json
/// {
///   "todo.md": {
///     "color": "teal",
///     "changed": "2026-10-13T18:40:00.000Z"
///   }
/// }
/// ```
///
/// Keeps unmarked documents too (`"color": null`), so taking a color off beats
/// an older color from another device. Other keys, e.g. `pinned` written
/// by older app versions, are ignored, and so are entries for paths in
/// other directories, which older app versions kept in one file.
abstract final class DocumentMarksFile {
  /// The marks in [bytes]. Skips entries it cannot read; `null` if the
  /// whole file is unreadable.
  static Map<String, StampedMark>? decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) return null;
    return {
      for (final MapEntry(:key, :value) in json.entries)
        if (_decodeEntry(value) case final stamped? when _isName(key))
          key: stamped,
    };
  }

  /// [marks] as JSON, sorted by name so diffs stay small.
  static Uint8List encode(Map<String, StampedMark> marks) {
    final names = marks.keys.toList()..sort();
    final json = {for (final name in names) name: _encodeEntry(marks[name]!)};
    return utf8.encode('${const JsonEncoder.withIndent('  ').convert(json)}\n');
  }

  /// Whether [key] names a file in the file's own directory.
  static bool _isName(String key) =>
      key.isNotEmpty && !key.contains('/') && key != '.' && key != '..';

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
