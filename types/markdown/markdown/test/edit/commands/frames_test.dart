import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';

import '../support/shown.dart';

String _after(String text, Command Function(Shown document) command) {
  final document = Shown.read(text);
  return document.run(command(document)).document.text;
}

void main() {
  group('Backspace at a frame\'s start', () {
    test('takes a block out of its quote, which splits around it', () {
      expect(
        _after('> a\n>\n> b\n>\n> c', (n) => RemoveFrame(n.leaf(1))),
        '> a\n\nb\n\n> c',
      );
      expect(_after('> a\n> b', (n) => RemoveFrame(n.leaf(0))), 'a\nb');
      expect(_after('> a\n>\n> b', (n) => RemoveFrame(n.leaf(0))), 'a\n\n> b');
    });

    test('makes a first item a paragraph above its list', () {
      expect(_after('- a\n- b', (n) => RemoveFrame(n.leaf(0))), 'a\n\n- b');
      expect(
        _after('- a\n  - b\n- c', (n) => RemoveFrame(n.leaf(0))),
        'a\n\n- b\n- c',
      );
    });

    test('makes another item a line of the item above', () {
      expect(
        _after('- a\n- b\n- c', (n) => RemoveFrame(n.leaf(1))),
        '- a\\\n  b\n- c',
      );
      expect(_after('- a\n-\n- c', (n) => RemoveFrame(n.leaf(1))), '- a\n- c');
      expect(
        _after('- a\n  - x\n- b', (n) => RemoveFrame(n.leaf(2))),
        '- a\n  - x\n\n  b',
      );
    });
  });

  test('Enter on an empty item ends the list there, shown only', () {
    final document = Shown.read('- a\n-\n- c');
    final (document: left, :selection) = document.run(
      Outdent(document.caret(1, 0)),
    );
    expect(left.text, '- a\n- c');
    expect(left.rows, ['a', '', 'c']);
    expect(selection, left.caret(1, 0));
  });

  group('indent', () {
    test('makes an item a subitem of the one above', () {
      expect(_after('- a\n- b', (n) => Indent(n.caret(1, 0))), '- a\n  - b');
      expect(
        _after('- a\n  1. x\n- b', (n) => Indent(n.caret(2, 0))),
        '- a\n  1. x\n  2. b',
      );
    });

    test('under a Done section, goes under the open item shown above', () {
      final document = Shown.read(
        '- [ ] a\n- [x] done\n- [ ] b',
        done: DoneSections(),
      );
      expect(document.rows, ['a', 'b', 'done done']);
      expect(canIndent(document.view, document.leaf(1)), isTrue);
      expect(
        document.run(Indent(document.caret(1, 0))).document.text,
        '- [ ] a\n  - [ ] b\n- [x] done',
      );
    });

    test('keeps the selection given, e.g. the user\'s during a swipe', () {
      final document = Shown.read('- a\n- b\n\nc');
      final user = document.caret(2, 1);
      final indented = document.run(Indent(document.caret(1, 0), after: user));
      expect(indented.document.text, '- a\n  - b\n\nc');
      expect(indented.selection, user);
      expect(
        document.run(Outdent(document.caret(1, 0), after: user)).selection,
        user,
      );
    });

    test('outdent puts an item after its parent with the items after it', () {
      expect(
        _after('- a\n  - b\n  - c', (n) => Outdent(n.caret(1, 0))),
        '- a\n- b\n  - c',
      );
    });

    test('outdent from an empty last item ends the list', () {
      final document = Shown.read('- a\n-');
      final edited = document.run(Outdent(document.caret(1, 0)));
      expect(edited.document.text, '- a');
      expect(edited.document.rows, ['a', '']);
    });

    test('leaving a quote\'s only list keeps the caret in the quote', () {
      final document = Shown.read('> -');
      final edited = document.run(Outdent(document.caret(0, 0)));
      expect(edited.document.rows, ['']);
      final at = (edited.selection as TextSelection).extent;
      expect(edited.document.view.rowOf(at.leaf), 0);
      expect(edited.document.doc.parentOf(at.leaf), isA<QuoteNode>());
    });

    test('outdent at the top takes an item out of its list', () {
      expect(
        _after('1. a\n2. b\n3. c', (n) => Outdent(n.caret(1, 0))),
        '1. a\n\nb\n\n3. c',
      );
      expect(_after('- a\n- b', (n) => Outdent(n.caret(0, 0))), 'a\n\n- b');
    });
  });
}
