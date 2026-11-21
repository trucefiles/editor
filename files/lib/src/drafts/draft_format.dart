import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'draft.dart';

/// How a draft is kept in one file: a short header, then the content.
///
/// The header is two lines: [_magic], then JSON with the path, whose file
/// the draft is for and how long the content is. A file whose content
/// isn't that long is not a draft (e.g. cut off), so it is never read as
/// one.
abstract final class DraftFormat {
  static const _magic = 'truce-draft 1';

  /// A header is never longer, so listing reads at most this much.
  static const headLimit = 16 * 1024;

  static final _newline = utf8.encode('\n').single;

  /// [draft] as the bytes of its file.
  static Uint8List encode(Draft draft) {
    final head = utf8.encode('$_magic\n${jsonEncode(_headJson(draft))}\n');
    return (BytesBuilder(copy: false)
          ..add(head)
          ..add(draft.content))
        .takeBytes();
  }

  static Map<String, Object> _headJson(Draft draft) => {
    'path': draft.head.path.value,
    ...switch (draft.head.of) {
      NewFileDraft(:final newSubfolder) => {
        if (newSubfolder) 'newSubfolder': true,
      },
      OwnDraft(:final part) => {'own': part},
    },
    'length': draft.content.length,
  };

  /// The header of the draft [id] that starts with [start] (at least its
  /// header, at most [headLimit] bytes), and where its content starts and
  /// ends; `null` if it is no draft of this format.
  static ({DraftHead head, int contentStart, int contentEnd})? readHead(
    String id,
    Uint8List start,
  ) {
    final firstEnd = start.indexOf(_newline);
    final secondEnd = firstEnd < 0 ? -1 : start.indexOf(_newline, firstEnd + 1);
    if (secondEnd < 0) return null;
    final String magic;
    final Object? json;
    try {
      magic = utf8.decode(start.sublist(0, firstEnd));
      json = jsonDecode(utf8.decode(start.sublist(firstEnd + 1, secondEnd)));
    } on FormatException {
      return null;
    }
    if (magic != _magic) return null;
    if (json case {'path': final String raw, 'length': final int length}
        when length >= 0) {
      final path = RelPath.parse(raw);
      final of = switch (json['own']) {
        final String part => OwnDraft(part),
        // An optional field: anything but `true` reads as its default, so
        // it never makes the draft unreadable.
        null => NewFileDraft(newSubfolder: json['newSubfolder'] == true),
        _ => null,
      };
      if (path != null && of != null) {
        return (
          head: DraftHead(id: id, path: path, of: of),
          contentStart: secondEnd + 1,
          contentEnd: secondEnd + 1 + length,
        );
      }
    }
    return null;
  }
}
