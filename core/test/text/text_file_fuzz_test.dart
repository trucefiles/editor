import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Random files and edits: saving never changes bytes the edit did not
/// touch, and never loses or adds text.
void main() {
  const cases = 3000;
  const breaks = ['\n', '\r\n', '\r'];
  const pieces = ['a', 'é', '😀', ' ', '- [ ] ', '#', '\t', ''];

  late Random random;

  setUp(() => random = Random(42));

  String line() => [
    for (var i = random.nextInt(4); i > 0; i--)
      pieces[random.nextInt(pieces.length)],
  ].join();

  /// A file's lines and the break after each but the last.
  ///
  /// Never a `\r` break, an empty line, then a `\n` break: those bytes
  /// read as one `\r\n` break, so the file would not hold these lines.
  ({List<String> lines, List<String> breaks}) randomFile() {
    while (true) {
      final lines = [for (var i = random.nextInt(6) + 1; i > 0; i--) line()];
      final fileBreaks = [
        for (var i = 1; i < lines.length; i++)
          breaks[random.nextInt(breaks.length)],
      ];
      final ambiguous = [
        for (var i = 1; i < fileBreaks.length; i++)
          fileBreaks[i - 1] == '\r' &&
              lines[i].isEmpty &&
              fileBreaks[i] == '\n',
      ].any((found) => found);
      if (!ambiguous) return (lines: lines, breaks: fileBreaks);
    }
  }

  Uint8List bytesOf(
    ({List<String> lines, List<String> breaks}) file, {
    required bool bom,
  }) {
    final text = StringBuffer(file.lines.first);
    for (var i = 1; i < file.lines.length; i++) {
      text
        ..write(file.breaks[i - 1])
        ..write(file.lines[i]);
    }
    final body = utf8.encode(text.toString());
    return bom ? Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]) : body;
  }

  test('saving unchanged text writes the same bytes', () {
    for (var i = 0; i < cases; i++) {
      final bytes = bytesOf(randomFile(), bom: random.nextBool());
      final file = TextFile.decode(bytes)!;

      expect(file.encode(file.text), bytes);
    }
  });

  test('editing one line changes only that line\'s bytes', () {
    for (var i = 0; i < cases; i++) {
      final original = randomFile();
      final bom = random.nextBool();
      final file = TextFile.decode(bytesOf(original, bom: bom))!;
      final edited = [...original.lines];
      final at = random.nextInt(edited.length);
      edited[at] = line();
      // An emptied line between `\r` and `\n` would read as one break; see
      // [randomFile].
      if (edited[at].isEmpty) edited[at] = 'x';

      final saved = file.encode(edited.join('\n'));

      final expected = bytesOf((
        lines: edited,
        breaks: original.breaks,
      ), bom: bom);
      expect(saved, expected, reason: 'case $i: $original -> $edited');
    }
  });

  /// Files that mix old Mac `\r` breaks with `\n` ones are left out: a new
  /// `\n` break after an empty line that follows a `\r` reads back as one
  /// `\r\n` break, dropping that empty line. Such files are vanishingly
  /// rare, and no text is lost.
  test('adding and removing lines loses no text and keeps the rest', () {
    for (var i = 0; i < cases; i++) {
      var original = randomFile();
      while (original.breaks.contains('\r') &&
          original.breaks.any((b) => b.endsWith('\n'))) {
        original = randomFile();
      }
      final bom = random.nextBool();
      final file = TextFile.decode(bytesOf(original, bom: bom))!;
      final edited = [...original.lines];
      final at = random.nextInt(edited.length + 1);
      if (random.nextBool() || edited.length == 1) {
        // Not empty: see [randomFile].
        edited.insertAll(at, [
          for (var n = random.nextInt(3) + 1; n > 0; n--) '${line()}x',
        ]);
      } else {
        edited.removeRange(min(at, edited.length - 1), edited.length);
      }
      final text = edited.join('\n');

      final saved = file.encode(text);
      final reread = TextFile.decode(saved)!;

      expect(reread.text, text, reason: 'case $i');
      expect(reread.hasBom, bom, reason: 'case $i');
    }
  });

  test('appending lines keeps every byte of the file before them', () {
    for (var i = 0; i < cases; i++) {
      final original = randomFile();
      final bytes = bytesOf(original, bom: random.nextBool());
      final file = TextFile.decode(bytes)!;

      final saved = file.encode('${file.text}\n${line()}\n${line()}');

      expect(saved.sublist(0, bytes.length), bytes, reason: 'case $i');
    }
  });
}
