import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';

import '../common/unchanged_ends.dart';

import 'lines.dart';

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
    final hasBom = _startsWithBom(bytes);
    final String raw;
    try {
      raw = utf8.decode(hasBom ? bytes.sublist(3) : bytes);
    } on FormatException {
      return null;
    }
    final breaks = [for (final m in anyLineBreak.allMatches(raw)) m[0]!];
    return TextFile._(
      raw.replaceAll(anyLineBreak, '\n'),
      hasBom: hasBom,
      lineBreak: breaks.firstOrNull ?? '\n',
      breaks: breaks,
    );
  }

  /// [bytes] as text to show and compare, as [decode] gives it: `\n`
  /// line breaks, no byte order mark. Only to show: bytes that are not
  /// valid UTF-8 show as replacement characters, so such text is never
  /// written.
  static String textToShow(Uint8List bytes) => utf8
      .decode(
        _startsWithBom(bytes) ? bytes.sublist(3) : bytes,
        allowMalformed: true,
      )
      .replaceAll(anyLineBreak, '\n');

  static bool _startsWithBom(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;

  /// A new file's style: no byte order mark, `\n` line breaks.
  const TextFile.empty()
    : this._('', hasBom: false, lineBreak: '\n', breaks: const []);

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

  /// The breaks between [lines]: a line the old text had keeps the break
  /// after it; a line that follows one it didn't have gets the break it
  /// had before it; only breaks between added lines get [lineBreak].
  List<String> _breaksFor(List<String> lines) {
    final old = _oldLinesOf(lines);
    return [
      for (final [before, after] in IterableZip([old, old.skip(1)]))
        switch ((before, after)) {
          (final before?, _) when before < _breaks.length => _breaks[before],
          (_, final after?) when after > 0 => _breaks[after - 1],
          _ => lineBreak,
        },
    ];
  }

  /// For each of [lines], the line of [text] it is: the same lines at
  /// the start and the end, and a line diff between them; `null` for a
  /// line it didn't have.
  List<int?> _oldLinesOf(List<String> lines) {
    final old = text.split('\n');
    final same = unchangedEnds(old, lines);
    final oldEnd = old.length - same.end;
    final middle = List<int?>.generate(
      oldEnd - same.start,
      (line) => same.start + line,
    );
    // The script turns the old middle into the new one, applied in order.
    final script = calculateListDiff(
      old.sublist(same.start, oldEnd),
      lines.sublist(same.start, lines.length - same.end),
      detectMoves: false,
    ).getUpdatesWithData();
    for (final update in script) {
      switch (update) {
        case DataRemove(:final position):
          middle.removeAt(position);
        case DataInsert(:final position):
          middle.insert(position, null);
        case DataChange() || DataMove():
          throw StateError('A list diff without moves has no changes or moves');
      }
    }
    return [
      ...List.generate(same.start, (line) => line),
      ...middle,
      ...List.generate(same.end, (line) => oldEnd + line),
    ];
  }
}
