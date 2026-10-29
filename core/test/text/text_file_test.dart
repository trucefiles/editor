import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

Uint8List utf8Of(String text) => utf8.encode(text);

void main() {
  test('round-trips \\n files unchanged', () {
    final bytes = utf8Of('# Title\nline\n');
    final file = TextFile.decode(bytes)!;

    expect(file.text, '# Title\nline\n');
    expect(file.encode(file.text), bytes);
  });

  test('edits \\r\\n files with \\n and saves \\r\\n', () {
    final file = TextFile.decode(utf8Of('a\r\nb\r\n'))!;

    expect(file.text, 'a\nb\n');
    expect(utf8.decode(file.encode('a\nc\n')), 'a\r\nc\r\n');
  });

  test('keeps old Mac \\r line breaks', () {
    final file = TextFile.decode(utf8Of('a\rb'))!;

    expect(file.text, 'a\nb');
    expect(utf8.decode(file.encode(file.text)), 'a\rb');
  });

  test('keeps the byte order mark', () {
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8Of('é')]);
    final file = TextFile.decode(bytes)!;

    expect(file.text, 'é');
    expect(file.encode(file.text), bytes);
  });

  test('refuses invalid UTF-8', () {
    expect(TextFile.decode(Uint8List.fromList([0xFF, 0xFE])), isNull);
  });

  test('new files use \\n and no byte order mark', () {
    expect(utf8.decode(const TextFile.empty().encode('a\nb')), 'a\nb');
  });

  test('withText keeps the byte style', () {
    final file = TextFile.decode(utf8Of('a\r\n'))!.withText('b\n');

    expect(file.text, 'b\n');
    expect(utf8.decode(file.encode(file.text)), 'b\r\n');
  });

  test('keeps each line\'s break in files that mix styles', () {
    final file = TextFile.decode(utf8Of('a\r\nb\nc\r\nd\n'))!;

    expect(file.text, 'a\nb\nc\nd\n');
    expect(utf8.decode(file.encode('a\nB\nc\nd\n')), 'a\r\nB\nc\r\nd\n');
  });

  test('new lines in a mixed file get its first break style', () {
    final file = TextFile.decode(utf8Of('a\r\nb\nc'))!;

    expect(utf8.decode(file.encode('a\nb\nx\ny\nc')), 'a\r\nb\nx\r\ny\nc');
  });

  test('reads \r and \r\n in one file as one break each', () {
    final file = TextFile.decode(utf8Of('a\rb\r\nc'))!;

    expect(file.text, 'a\nb\nc');
    expect(utf8.decode(file.encode(file.text)), 'a\rb\r\nc');
  });

  test('withText remembers the breaks it saved with', () {
    final saved = TextFile.decode(utf8Of('a\nb\r\nc'))!.withText('a\nb\nc\nd');

    expect(utf8.decode(saved.encode('a\nb\nc\nd')), 'a\nb\r\nc\nd');
  });

  test('text to show drops the byte order mark and breaks as decode does', () {
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8Of('a\r\nb')]);

    expect(TextFile.textToShow(bytes), 'a\nb');
    expect(TextFile.textToShow(bytes), TextFile.decode(bytes)!.text);
  });

  test('text to show shows invalid UTF-8 as replacement characters', () {
    expect(TextFile.textToShow(Uint8List.fromList([0x61, 0xFF])), 'a\uFFFD');
  });
}
