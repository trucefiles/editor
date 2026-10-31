import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/commands/items.dart';

import '../support/shown.dart';

/// The items of [document], in file order.
List<ItemNode> _items(Shown document) =>
    nodesIn(document.doc.root).whereType<ItemNode>().toList();

String _after(String text, Command Function(Shown document) command) {
  final document = Shown.read(text);
  return document.run(command(document)).document.text;
}

void main() {
  test('a tap on a box checks it', () {
    expect(
      _after('- [ ] a', (n) => Toggle(_items(n).first.id, n.caret(0, 0))),
      '- [x] a',
    );
  });

  test('the delete button removes an item with its subitems', () {
    final document = Shown.read('- a\n  - b\n- c');
    final (document: after, :selection) = document.run(
      DeleteItem(_items(document).first.id),
    );
    expect(after.text, '- c');
    expect(selection, after.caret(0, 0));
    expect(_after('- a', (n) => DeleteItem(_items(n).first.id)), '');
  });

  test('Add item puts an empty item at the end', () {
    final document = Shown.read('- [x] a');
    final list = document.doc.root.children.single.id;
    final (document: after, :selection) = document.run(AddItem(list));
    expect(after.text, '- [x] a\n- [ ] ');
    expect(selection, after.caret(1, 0));
  });

  test('Add item puts an empty item first, or after the open items', () {
    final document = Shown.read('- [ ] a\n- [x] b');
    final list = document.doc.root.children.single.id;
    String added(AddAt at) => document.run(AddItem(list, at: at)).document.text;
    expect(added(AddAt.first), '- [ ] \n- [ ] a\n- [x] b');
    expect(added(AddAt.afterOpen), '- [ ] a\n- [ ] \n- [x] b');
  });

  test('a drop moves an item with its subitems', () {
    expect(
      _after('- a\n  - b\n- c', (n) {
        final [a, _, c] = _items(n);
        return MoveItem(a.id, c.id, below: true, selection: n.caret(0, 0));
      }),
      '- c\n- a\n  - b',
    );
  });

  test('an item of two paragraphs keeps them apart in a tight list', () {
    expect(
      _after('- a\n  - s\n\n  - b\n\n    c', (n) {
        final items = _items(n);
        return MoveItem(
          items[2].id,
          items[0].id,
          below: true,
          selection: n.caret(0, 0),
        );
      }),
      '- a\n  - s\n- b\n\n  c',
    );
  });

  test('checked items move to the end of their lists', () {
    expect(
      _after(
        '- [x] a\n- [ ] b\n- [x] c\n- [ ] d',
        (n) => MoveToEnd(n.caret(0, 0)),
      ),
      '- [ ] b\n- [ ] d\n- [x] a\n- [x] c',
    );
  });

  test('clearing checked items removes them', () {
    expect(
      _after(
        '- [x] a\n- [ ] b\n\n> - [x] c',
        (n) => ClearChecked(n.caret(1, 0)),
      ),
      '- [ ] b',
    );
  });

  test('the heading button cycles none, 1, 2, 3, none', () {
    expect([null, 1, 2, 3, 4].map(nextHeadingLevel), [1, 2, 3, null, null]);
    expect(_after('a', (n) => SetHeading(n.place(0, 0), 2)), '## a');
    expect(_after('a\\\nb', (n) => SetHeading(n.place(0, 0), 3)), '### a b');
    expect(
      _after('Title\n===', (n) => SetHeading(n.place(0, 0), 2)),
      'Title\n---',
    );
    expect(_after('# a', (n) => SetHeading(n.place(0, 0), null)), 'a');
  });

  group('an item dropped right next to', () {
    final document = Shown.read('- a\n  - b\n  - c\n- d\n\n1. e');
    final [a, b, c, d, e] = _items(document);
    bool stays(ItemNode item, ItemNode target, {required bool below}) =>
        staysInPlace(document.doc, item.id, target.id, below: below);

    test('itself, its next item from above or its previous one from below '
        'stays in place', () {
      expect(stays(b, b, below: true), isTrue);
      expect(stays(b, c, below: false), isTrue);
      expect(stays(c, b, below: true), isTrue);
    });

    test('its parent from below, as its first subitem, stays in place', () {
      expect(stays(b, a, below: true), isTrue);
      expect(stays(c, a, below: true), isFalse);
    });

    test('a previous item with subitems, from below, moves', () {
      expect(stays(d, a, below: true), isFalse);
    });

    test('an item of another list moves', () {
      expect(stays(d, e, below: false), isFalse);
    });
  });
}
