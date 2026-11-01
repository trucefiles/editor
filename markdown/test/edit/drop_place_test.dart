import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/edit/drop_place.dart';
import 'package:truce_markdown/src/view/rows.dart';

import 'support/shown.dart';

/// The items of [document], in file order.
List<ItemNode> _items(Shown document) =>
    nodesIn(document.doc.root).whereType<ItemNode>().toList();

void main() {
  group('an item dropped right next to', () {
    final document = Shown.read('- a\n  - b\n  - c\n- d\n\n1. e');
    final [a, b, c, d, e] = _items(document);
    ({NodeId item, bool below})? place(
      ItemNode item,
      ItemNode target, {
      required bool below,
    }) => dropPlace(document.view, item.id, target.id, below: below);

    test('itself, its next item from above or its previous one from below '
        'stays in place', () {
      expect(place(b, b, below: true), isNull);
      expect(place(b, c, below: false), isNull);
      expect(place(c, b, below: true), isNull);
    });

    test('its parent from below, as its first subitem, stays in place', () {
      expect(place(b, a, below: true), isNull);
      expect(place(c, a, below: true), (item: b.id, below: false));
    });

    test('a previous item with subitems, from below, goes above its first '
        'subitem', () {
      expect(place(d, a, below: true), (item: b.id, below: false));
    });

    test('an item of another list moves', () {
      expect(place(d, e, below: false), (item: e.id, below: false));
    });

    test('the next row shown in a Done section stays in place', () {
      final done = Shown.read(
        '- [ ] a\n- [x] b\n- [ ] c',
        done: DoneSections(),
      );
      final [a, _, c] = _items(done);
      expect(dropPlace(done.view, a.id, c.id, below: false), isNull);
      expect(dropPlace(done.view, a.id, c.id, below: true), (
        item: c.id,
        below: true,
      ));
    });
  });
}
