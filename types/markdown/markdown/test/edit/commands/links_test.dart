import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commands/links.dart';
import 'package:truce_markdown/src/edit/selection.dart';

import '../support/shown.dart';

/// [text] after the link dialog sets [shows] linking [url] over [from]
/// to [to] of its first row; with the selection after.
(String, Selection?) _linked(
  String text,
  int from,
  int to,
  String shows,
  String url,
) {
  final document = Shown.read(text);
  final edited = document.run(
    SetLink(
      TextSelection(document.place(0, from), document.place(0, to)),
      shows,
      url,
    ),
  );
  return (edited.document.text, edited.selection);
}

String _unlinked(String text, int offset) {
  final document = Shown.read(text);
  return document.run(RemoveLink(document.place(0, offset))).document.text;
}

void main() {
  group('setting a link', () {
    test('links the selected text, keeping its formats', () {
      expect(_linked('a **b** c', 2, 3, 'b', 'u').$1, 'a **[b](u)** c');
    });

    test('puts in new text, or the url if none, the caret after it', () {
      final (text, selection) = _linked('a b', 2, 2, 'site', 'u');
      expect(text, 'a [site](u)b');
      expect((selection as TextSelection).extent.offset, 6);
      expect(_linked('a b', 2, 3, '', 'u').$1, 'a [u](u)');
    });

    test('keeps a link\'s spelling when its url stays', () {
      expect(
        _linked('[a][r]\n\n[r]: u', 0, 1, 'b', 'u').$1,
        '[b][r]\n\n[r]: u',
      );
    });

    test('changes a link\'s url', () {
      expect(_linked('[a](u)', 0, 1, 'a', 'v').$1, '[a](v)');
    });
  });

  group('removing a link', () {
    test('keeps its text', () {
      expect(_unlinked('x [a **b**](u) y', 3), 'x a **b** y');
      expect(_unlinked('x [ab](u) y', 4), 'x ab y');
    });

    test('is possible on a link, not on text GFM reads as one', () {
      final document = Shown.read('[a](u) www.example.com');
      expect(canRemoveLink(document.view, document.place(0, 0)), isTrue);
      expect(canRemoveLink(document.view, document.place(0, 3)), isFalse);
      expect(canRemoveLink(document.view, document.place(0, 8)), isFalse);
    });
  });

  group('the link here', () {
    LinkHere? here(String text, int from, [int? to]) {
      final document = Shown.read(text);
      return linkHere(
        document.view,
        TextSelection(document.place(0, from), document.place(0, to ?? from)),
      );
    }

    test('at a caret in it, or right after it, is all of it', () {
      for (final offset in [3, 4, 6]) {
        final link = here('a [link](https://x.io) b', offset)!;
        expect(
          (link.text, link.url, link.removable),
          ('link', 'https://x.io', true),
        );
        expect(link.range.base.offset, 2);
        expect(link.range.extent.offset, 6);
      }
    });

    test('over part of it, is all of it; over more, none', () {
      expect(here('a [link](u) b', 3, 5)?.text, 'link');
      expect(here('a [link](u) b', 1, 4), isNull);
    });

    test('is none before it or in plain text', () {
      expect(here('a [link](u) b', 1), isNull);
      expect(here('plain', 2), isNull);
    });

    test('of text GFM reads as a link cannot be removed', () {
      final link = here('see www.x.io now', 6)!;
      expect(link.text, 'www.x.io');
      expect(link.removable, isFalse);
    });
  });
}
