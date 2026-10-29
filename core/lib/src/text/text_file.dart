import 'dart:convert';
import 'dart:typed_data';

import '../common/unchanged_ends.dart';

/// A UTF-8 text file decoded for editing.
///
/// Editors work on [text] with `\n` line breaks only. [encode] puts the
/// file's own byte order mark and line breaks back, so saving changes only
/// the lines that were edited.
final class TextFile {
  const TextFile._(
    this.text, {
    required this.hasBom,
    required this.lineBreak,
    required this._breaks,
  });

  /// Decodes [bytes]; `null` if they are not valid UTF-8, so such files are
  /// never rewritten with replacement characters.
  ///
  /// Each line keeps its own line break, also in files that mix styles.
  /// The first one found is the file's style, for new lines; `\n` if there
  /// is none.
  static TextFile? decode(Uint8List bytes) {
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
    final String raw;
    try {
      raw = utf8.decode(hasBom ? bytes.sublist(3) : bytes);
    } on FormatException {
      return null;
    }
    final breaks = [for (final m in _anyBreak.allMatches(raw)) m[0]!];
    return TextFile._(
      raw.replaceAll(_anyBreak, '\n'),
      hasBom: hasBom,
      lineBreak: breaks.firstOrNull ?? '\n',
      breaks: breaks,
    );
  }

  /// A new file's style: no byte order mark, `\n` line breaks.
  const TextFile.empty()
    : this._('', hasBom: false, lineBreak: '\n', breaks: const []);

  static final _anyBreak = RegExp('\r\n|\r|\n');

  /// Content with `\n` line breaks.
  final String text;

  final bool hasBom;

  /// `\n`, `\r\n` or `\r`: the break for new lines.
  final String lineBreak;

  /// The break after each line of [text] but the last, as in the file.
  final List<String> _breaks;

  /// [newText] (with `\n` line breaks) in this file's byte style.
  Uint8List encode(String newText) {
    final lines = newText.split('\n');
    final breaks = _breaksFor(lines);
    final buffer = StringBuffer(lines.first);
    for (var i = 1; i < lines.length; i++) {
      buffer
        ..write(breaks[i - 1])
        ..write(lines[i]);
    }
    final body = utf8.encode(buffer.toString());
    return hasBom ? Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]) : body;
  }

  /// This file's style with [newText] as content, e.g. after saving it.
  TextFile withText(String newText) => TextFile._(
    newText,
    hasBom: hasBom,
    lineBreak: lineBreak,
    breaks: _breaksFor(newText.split('\n')),
  );

  /// The breaks between [lines]: the unchanged lines before and after the
  /// edited part keep theirs, on both sides; other breaks get [lineBreak].
  List<String> _breaksFor(List<String> lines) {
    final old = text.split('\n');
    final same = unchangedEnds(old, lines);
    final shift = old.length - lines.length;
    return [
      for (var i = 0; i < lines.length - 1; i++)
        if (i < same.start && i < _breaks.length)
          _breaks[i]
        else if (i + 1 >= lines.length - same.end && i + shift >= 0)
          _breaks[i + shift]
        else
          lineBreak,
    ];
  }
}
