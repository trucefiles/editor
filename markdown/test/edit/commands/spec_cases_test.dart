import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

/// Edits the command fuzz found wrong on the CommonMark spec examples.
/// Each edited document reads back as it prints (see `Shown.run`).

/// The leaf of the [index]th text row.
NodeId _text(Shown document, int index) =>
    document.view.rows.whereType<TextRow>().elementAt(index).leaf.id;

TextSelection _caret(Shown document, int row, int offset) =>
    TextSelection.caret(Place(_text(document, row), offset));

TextSelection _range(Shown document, int row, int from, int to) =>
    TextSelection(
      Place(_text(document, row), from),
      Place(_text(document, row), to),
    );

({Shown document, Selection selection}) _run(
  String text,
  Command Function(Shown document) command,
) {
  final document = Shown.read(text);
  return document.run(command(document));
}

String _framed(String text, FrameKind kind, {int row = 0}) =>
    _run(text, (d) => SetFrame(_caret(d, row, 0), kind)).document.text;

String _heading(String text) =>
    _run(text, (d) => SetHeading(Place(_text(d, 0), 0), 1)).document.text;

void main() {
  group('a block put in a new item', () {
    test('drops its first line\'s indent, which would move the content', () {
      expect(
        _framed('  Foo *bar\nbaz*\n====', FrameKind.bullet),
        '- Foo *bar\n  baz*\n  ====',
      );
      expect(
        _framed('   ```\naaa\n  ```\n', FrameKind.bullet),
        '- ```\n  aaa\n  ```\n',
      );
    });

    test('escapes text that reads as a rule after its bullet', () {
      // Its first line would read otherwise under the marker, so the
      // paragraph is written anew.
      expect(
        _framed('--\n**\n_ _\n', FrameKind.bullet),
        '- \\--\n  \\*\\*\n  \\_ \\_\n',
      );
    });

    test('writes code after a tab anew when the marker changes', () {
      expect(
        _framed('-\t\tfoo\nx\n', FrameKind.numbered),
        '1. ```\n     foo\n   ```\nx\n',
      );
    });
  });

  group('a block right after a list stays out of it', () {
    test('a kept HTML block loses its first line\'s indent', () {
      expect(
        _framed(
          '<table>\n\n  <tr>\n\n    <td>\n      Hi\n    </td>\n\n  </tr>\n',
          FrameKind.bullet,
        ),
        '<table>\n\n  <tr>\n\n'
        '- ```\n  <td>\n    Hi\n  </td>\n  ```\n\n</tr>\n',
      );
    });

    test('a list of the same kind joins it', () {
      expect(
        _framed('fox\n\n11) a\n   - b\n', FrameKind.bullet, row: 1),
        'fox\n\n- a\n- b\n',
      );
    });

    test('code whose first line reaches into the list is fenced', () {
      final edited = _run(
        '1. a\n\n  2. b\n\n    3. c\n',
        (d) => DeleteRange(_range(d, 2, 0, 2)),
      );
      expect(edited.document.text, '1. a\n\n  2. b\n\n```\n c\n```\n');
    });
  });

  test('a split above a tabbed item writes its parts anew', () {
    final edited = _run(
      ' - foob\n   - aio\n\t - baz',
      (d) => SplitBlock(_range(d, 1, 1, 2)),
    );
    expect(edited.document.text, ' - foob\n   - a\n   - o\n     - baz');
  });

  test('a deletion that takes a tab\'s item writes the parts anew', () {
    final edited = _run(
      ' - foo\n   - bar\n\t - baz',
      (d) => DeleteRange(
        TextSelection(Place(_text(d, 0), 3), Place(_text(d, 1), 2)),
      ),
    );
    expect(edited.document.text, ' - foor\n   - baz');
  });

  test('a line end character leaves code', () {
    final edited = _run(
      'foo&#10;bar',
      (d) => ToggleStyle(_range(d, 0, 1, 6), TextFormat.code),
    );
    expect(edited.document.text, 'f`oo`&#10;`ba`r');
  });

  test('a deletion over blocks leaves the caret on what shows', () {
    final split = _run(
      '# x\n## a\n[foo]: /bar\n###',
      (d) => SplitBlock(_caret(d, 0, 0)),
    ).document;
    final texts = split.view.rows.whereType<TextRow>().toList();
    final (:document, :selection) = split.run(
      DeleteRange(
        TextSelection(
          Place(texts.first.leaf.id, 0),
          Place(texts.last.leaf.id, 0),
        ),
      ),
    );
    expect(
      document.view.rowOf((selection as TextSelection).base.leaf),
      isNotNull,
    );
  });

  group('a heading in one line writes in one line', () {
    test('inline HTML', () {
      expect(_heading('foo <!-- a --\nb -->'), '# foo <!-- a -- b -->');
    });

    test('an image', () {
      expect(_heading('x ![a\nb](c "t\nu") y'), '# x ![a b](c "t u") y');
    });

    test('a link', () {
      expect(
        _heading('[l ink](   /uri\n    "title"  )'),
        '# [l ink](/uri "title")',
      );
    });

    test('a code span', () {
      expect(_heading('`code\\\nspan`'), '# `code\\ span`');
    });
  });

  group('links', () {
    test('references whose definition the edit took lead there inline', () {
      final edited = _run(
        'x\n\n[a]: /u\n\nsee [a] ![a]',
        (d) => DeleteRange(
          TextSelection(Place(_text(d, 0), 1), Place(_text(d, 1), 0)),
        ),
      );
      expect(edited.document.text, 'xsee [a](/u) ![a](/u)');
    });

    test('a bare link typed before an autolink', () {
      final edited = _run(
        '**a<https://foo.bar/?q=**>',
        (d) => InsertText(Place(_text(d, 0), 2), 'www.x.io', Formatting.plain),
      );
      expect(
        edited.document.text,
        '\\*\\*[www.x.ioa](http://www.x.ioa)<https://foo.bar/?q=**>',
      );
    });

    test('a shortcut reference whose text changed keeps its label', () {
      final document = Shown.read('[bar\\\\]: /uri\n\n[bar\\\\]\n');
      final leaf = _text(document, 0);
      final link = document
          .textOf(document.view.rowOf(leaf)!)
          .pieces
          .first
          .formatting;
      final edited = document.run(InsertText(Place(leaf, 3), '\\', link));
      expect(
        edited.document.text,
        '[bar\\\\]: /uri\n\n[bar\\\\\\\\][bar\\\\]\n',
      );
    });
  });

  test('a line break that would make a link definition is escaped', () {
    final edited = _run('[\n `]:www.b ci', (d) => LineBreak(_caret(d, 0, 10)));
    expect(edited.document.text, '\\[\n\\`]:www.b\\\nci');
  });
}
