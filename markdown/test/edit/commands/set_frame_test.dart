import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

/// [text] after [kind] is set on its rows [from] to [to].
String _framed(String text, FrameKind kind, [int from = 0, int? to]) {
  final document = Shown.read(text);
  return document
      .run(
        SetFrame(
          TextSelection(document.place(from, 0), document.place(to ?? from, 0)),
          kind,
        ),
      )
      .document
      .text;
}

void main() {
  group('a box', () {
    test('goes on items that have none, and off where all have one', () {
      expect(
        _framed('- a\n- [x] b', FrameKind.checkbox, 0, 1),
        '- [ ] a\n- [x] b',
      );
      expect(_framed('- [ ] a\n- [x] b', FrameKind.checkbox, 0, 1), '- a\n- b');
    });

    test('makes text a list of boxes', () {
      expect(_framed('a\n\nb', FrameKind.checkbox, 0, 1), '- [ ] a\n- [ ] b');
    });
  });

  group('bullet or numbered', () {
    test('changes the whole list', () {
      expect(_framed('- a\n- b', FrameKind.numbered, 1), '1. a\n2. b');
    });

    test('of the list\'s own kind takes the items out of it', () {
      expect(
        _framed('1. a\n2. b\n3. c', FrameKind.numbered, 1),
        '1. a\n\nb\n\n3. c',
      );
    });

    test('of the list\'s own kind leaves an empty item\'s place, the file '
        'one list until it gets text', () {
      final document = Shown.read('1. a\n2.\n3. b');
      final edited = document.run(
        SetFrame(document.caret(1, 0), FrameKind.numbered),
      );
      expect(edited.document.text, '1. a\n2. b');
      expect(edited.document.rows, ['a', '', 'b']);
      expect(edited.selection, edited.document.caret(1, 0));
    });

    test('of the list\'s own kind keeps what an item shows', () {
      final document = Shown.read('1. a\n2.');
      final spaced = document
          .run(InsertText(document.place(1, 0), ' ', Formatting.plain))
          .document;
      final edited = spaced.run(
        SetFrame(spaced.caret(1, 1), FrameKind.numbered),
      );
      expect(edited.document.rows, ['a', ' ']);
      expect(edited.selection, edited.document.caret(1, 1));
    });

    test('makes text items, joining a list of its kind', () {
      expect(_framed('a', FrameKind.bullet), '- a');
      expect(_framed('- a\n\nb', FrameKind.bullet, 1), '- a\n- b');
      expect(
        _framed('a\n\n- b\n\nc', FrameKind.bullet, 0, 2),
        '- a\n- b\n- c',
        reason: 'a list takes text on both sides',
      );
    });
  });

  group('a quote', () {
    test('wraps blocks, and goes off where all are quoted', () {
      expect(_framed('a\n\nb', FrameKind.quote, 0, 1), '> a\n>\n> b');
      expect(_framed('> a\n>\n> b', FrameKind.quote, 0), 'a\n\n> b');
    });

    test('in a list wraps the items\' text', () {
      expect(_framed('- a\n  - b', FrameKind.quote), '- > a\n  - b');
    });
  });
}
