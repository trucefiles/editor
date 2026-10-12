import 'dart:convert';
import 'dart:typed_data';

/// A UTF-8 text file decoded for editing.
///
/// Editors work on [text] with `\n` line breaks only. [encode] puts the
/// file's own byte order mark and line break back, so saving changes only
/// the lines that were edited.
final class TextFile {
  const TextFile._(this.text, {required this.hasBom, required this.lineBreak});

  /// Decodes [bytes]; `null` if they are not valid UTF-8, so such files are
  /// never rewritten with replacement characters.
  ///
  /// The first line break found is taken as the file's style; `\n` if
  /// there is none. A file mixing styles is saved with that first one.
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
    final lineBreak = _firstLineBreak(raw);
    return TextFile._(
      lineBreak == '\n' ? raw : raw.replaceAll(lineBreak, '\n'),
      hasBom: hasBom,
      lineBreak: lineBreak,
    );
  }

  /// A new file's style: no byte order mark, `\n` line breaks.
  const TextFile.empty() : this._('', hasBom: false, lineBreak: '\n');

  /// Content with `\n` line breaks.
  final String text;

  final bool hasBom;

  /// `\n`, `\r\n` or `\r`.
  final String lineBreak;

  /// [newText] (with `\n` line breaks) in this file's byte style.
  Uint8List encode(String newText) {
    final body = utf8.encode(
      lineBreak == '\n' ? newText : newText.replaceAll('\n', lineBreak),
    );
    return hasBom ? Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]) : body;
  }

  /// This file's style with [newText] as content, e.g. after saving it.
  TextFile withText(String newText) =>
      TextFile._(newText, hasBom: hasBom, lineBreak: lineBreak);

  static String _firstLineBreak(String raw) {
    final index = raw.indexOf(RegExp('[\r\n]'));
    if (index < 0 || raw[index] == '\n') return '\n';
    return raw.startsWith('\r\n', index) ? '\r\n' : '\r';
  }
}
