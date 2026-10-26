/// Taking a text out of its innermost item or quote.
library;

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import '../text_places.dart';
import 'lifted_items.dart';

/// Backspace at the start of [leaf], the first text of its innermost item
/// or quote: that frame goes. Out of a quote, the leaf goes one level
/// out, the quote split around it. A first item's blocks go above its
/// list; another item's text becomes a line of the item above, after a
/// line break, its other blocks following there.
Change removeFrame(ViewRows view, NodeId leaf) {
  final doc = view.doc;
  final caret = TextSelection.caret(Place(leaf, 0));
  return switch (doc.parentOf(leaf)) {
    final QuoteNode quote => _outOfQuote(view, quote, leaf),
    final ItemNode item => switch (doc.parentOf(item.id)! as ListNode) {
      final list when list.items.first == item => _aboveList(
        view,
        list,
        item,
        caret,
      ),
      final list => _intoItemAbove(view, list, item, caret),
    },
    _ => (doc: doc, selection: caret),
  };
}

/// Enter in [item], an empty item at a list's top level: it leaves the
/// list, its empty paragraph showing where it was, between the list's
/// two parts (the file keeps one list until it gets text); in place of
/// the list if it was its only item.
Change leaveList(ViewRows view, ItemNode item) {
  final doc = view.doc;
  final list = doc.parentOf(item.id)! as ListNode;
  final paragraph = item.children.single;
  final index = list.items.indexOf(item);
  final fresh = doc.freshIds;
  final before = list.items.take(index).toList();
  final after = list.items.skip(index + 1).toList();
  return (
    doc: doc.edited({
      list.id: [
        if (before.isNotEmpty) list.withChildren(before),
        paragraph,
        if (after.isNotEmpty)
          before.isEmpty
              ? list.withChildren(after)
              : listPart(
                  list.withChildren([...before, ...after]),
                  after,
                  fresh,
                ),
      ],
    }, fresh: fresh),
    selection: TextSelection.caret(Place(paragraph.id, 0)),
  );
}

/// [leaf] one level out of [quote], which splits around it: its first
/// part keeps its id.
Change _outOfQuote(ViewRows view, QuoteNode quote, NodeId leaf) {
  final doc = view.doc;
  final fresh = doc.freshIds;
  final index = quote.children.indexWhere((child) => child.id == leaf);
  final before = quote.children.take(index).toList();
  final after = quote.children.skip(index + 1).toList();
  return (
    doc: doc.edited({
      quote.id: [
        if (before.isNotEmpty) quote.withChildren(before),
        quote.children[index],
        if (after.isNotEmpty)
          before.isEmpty
              ? quote.withChildren(after)
              : QuoteNode(fresh.take(), after),
      ],
    }, fresh: fresh),
    selection: TextSelection.caret(Place(leaf, 0)),
  );
}

/// [item], its list's first, gone: its blocks above [list], subitems
/// going on in the list where they are of its kind; the caret stays.
Change _aboveList(
  ViewRows view,
  ListNode list,
  ItemNode item,
  TextSelection caret,
) {
  final rest = list.items.skip(1).toList();
  final children = item.children;
  final (lifted, joins) = switch (children.last) {
    final ListNode last when last.kind == list.kind && rest.isNotEmpty => (
      children.take(children.length - 1).toList(),
      [...last.items, ...rest],
    ),
    _ => (children, rest),
  };
  return (
    doc: view.doc.edited({
      list.id: [...lifted, if (joins.isNotEmpty) list.withChildren(joins)],
    }),
    selection: caret,
  );
}

/// [item]'s text a line of the item above it in [list], after a line
/// break at the end of that item's last paragraph (where the item ends
/// otherwise, the item's blocks follow there whole); its other blocks
/// follow there.
Change _intoItemAbove(
  ViewRows view,
  ListNode list,
  ItemNode item,
  TextSelection caret,
) {
  final doc = view.doc;
  final above = list.items[list.items.indexOf(item) - 1];
  final first = item.children.first;
  final last = above.children.last;
  if (first is ParagraphNode && last is ParagraphNode) {
    final shown = last.text;
    final text = first.text;
    final joined = withLeafText(
      last,
      text.isEmpty ? shown : shown + VisibleText([HardBreakPiece()]) + text,
    );
    return (
      doc: doc.edited({
        item.id: const [],
        above.id: [
          above.withChildren([
            ...above.children.take(above.children.length - 1),
            joined,
            ...item.children.skip(1),
          ]),
        ],
      }),
      selection: TextSelection.caret(
        Place(last.id, text.isEmpty ? shown.length : shown.length + 1),
      ),
    );
  }
  return (
    doc: doc.edited({
      item.id: const [],
      above.id: [
        above.withChildren([...above.children, ...item.children]),
      ],
    }),
    selection: caret,
  );
}
