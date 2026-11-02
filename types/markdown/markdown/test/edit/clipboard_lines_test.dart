import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/clipboard_lines.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import 'support/shown.dart';

/// The lines copied from [text], from its first text row's [from] to its
/// last text row's [to].
List<VisibleText> _copied(String text, int from, int to) {
  final view = Shown.read(text).view;
  final rows = view.rows.whereType<TextRow>();
  return copiedLines(
    view,
    TextSelection(
      Place(rows.first.leaf.id, from),
      Place(rows.last.leaf.id, to),
    ),
  );
}

void main() {
  test('plain text is a line for each line break', () {
    final lines = plainLines('a\r\nb\rc\n', Formatting.plain);
    expect([for (final line in lines) line.text], ['a', 'b', 'c', '']);
  });

  test('a copy is a line for each text place, from the range on', () {
    final lines = _copied('ab\n\n---\n\n- cd', 1, 1);
    expect(plainTextOf(lines), 'b\nc');
  });

  test('a copy keeps styles, splits at line breaks, drops objects', () {
    final lines = _copied('**a**\\\nb\nc ![i](u)', 0, 7);
    expect([for (final line in lines) line.text], ['a', 'b c ']);
    expect(lines.first.formattingAt(0).has(TextFormat.strong), isTrue);
  });

  test('a copy of code is a line for each of its lines', () {
    expect(plainTextOf(_copied('```\na\nb\n```\nc', 0, 1)), 'a\nb\nc');
  });
}
