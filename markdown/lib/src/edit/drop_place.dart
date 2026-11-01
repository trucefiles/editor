import '../doc/doc_nodes.dart';
import '../view/rows.dart';

/// Where [item], dropped right next to [target]'s row, [below] it or
/// above, goes in the tree: the item it goes next to, and whether below
/// it; below a row whose subitems show under it, that is above its first
/// subitem. `null` where the item stays where it shows: on its own row,
/// or right next to it among the rows as shown, in its own list.
({NodeId item, bool below})? dropPlace(
  ViewRows view,
  NodeId item,
  NodeId target, {
  required bool below,
}) {
  final doc = view.doc;
  final place = switch (doc.nodeOf(target)) {
    ItemNode(children: [_, ListNode(:final items), ...]) when below => (
      item: items.first.id,
      below: false,
    ),
    _ => (item: target, below: below),
  };
  if (place.item == item) return null;
  final sameList = doc.parentOf(place.item)?.id == doc.parentOf(item)?.id;
  return sameList && _shownNextTo(view, item, place.item, below: place.below)
      ? null
      : place;
}

/// Whether [item]'s rows show right [below] [other]'s rows, or right
/// above them.
bool _shownNextTo(
  ViewRows view,
  NodeId item,
  NodeId other, {
  required bool below,
}) {
  final (upper, lower) = below ? (other, item) : (item, other);
  return switch ((view.rowsOf(upper), view.rowsOf(lower))) {
    ((:final last, first: _), (:final first, last: _)) => first == last + 1,
    _ => false,
  };
}
