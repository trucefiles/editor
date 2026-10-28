import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  List<String> texts(TextLines lines) => [
    for (final line in lines.lines) line.text,
  ];

  test('reads lines with their endings, the mark kept apart', () {
    final lines = TextLines.read('﻿a\r\nb\nc');
    expect(texts(lines), ['a', 'b', 'c']);
    expect(lines.byteOrderMark, isTrue);
    expect(lines.text, '﻿a\r\nb\nc');
  });

  test('a line edited keeps its id and ending; a new one ends as most do', () {
    final lines = TextLines.read('a\r\nb\r\nc\n');
    final b = lines.lines[1].id;
    final next = lines.withLines(1, 2, [(id: b, text: 'b2\nnew')]);
    expect(next.text, 'a\r\nb2\r\nnew\r\nc\n');
    expect(next.lines[1].id, b);
    expect(next.indexOf(b), 1);
  });

  test('the last line ends with none', () {
    final lines = TextLines.read('a\nb');
    final next = lines.withLines(1, 2, []);
    expect(next.text, 'a');
  });

  test('text instead keeps the ids of unchanged lines at both ends', () {
    final lines = TextLines.read('a\nb\nc');
    final next = lines.withText('a\nx\nc');
    expect(next.lines.first.id, lines.lines.first.id);
    expect(next.lines.last.id, lines.lines.last.id);
    expect(next.lines[1].id, isNot(lines.lines[1].id));
    expect(next.text, 'a\nx\nc');
  });

  test('text instead may add or drop the mark', () {
    expect(TextLines.read('a').withText('﻿a').text, '﻿a');
    expect(TextLines.read('﻿a').withText('a').text, 'a');
  });
}
