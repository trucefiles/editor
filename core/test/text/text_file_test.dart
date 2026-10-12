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
}
