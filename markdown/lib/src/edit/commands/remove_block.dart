import '../../doc/doc_nodes.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';

/// [block], one without text (a divider), gone, as one character is.
/// With [caret], a place in a text that stays (Backspace or Delete right
/// next to the block), the caret stays there. Else (the block was
/// selected) it goes to the end of the text above if [backward], else to
/// the start of the next text, or the other way where there is none.
/// Where the block is all its item shows as its own line, an empty text
/// takes its place, so the item stays as an empty one; without [caret],
/// the caret goes into it.
Change removeBlock(
  ViewRows view,
  NodeId block, {
  required bool backward,
  Place? caret,
}) {
  final kept = caret == null ? null : TextSelection.caret(caret);
  if (view.doc.parentOf(block)
      case ItemNode(children: [final first, ...final rest])
      when first.id == block && (rest.isEmpty || rest.first is ListNode)) {
    final fresh = view.doc.freshIds;
    final text = emptyParagraph(fresh);
    return (
      doc: view.doc.edited({
        block: [text],
      }, fresh: fresh),
      selection: kept ?? TextSelection.caret(Place(text.id, 0)),
    );
  }
  return (
    doc: view.doc.edited({block: const []}),
    selection: kept ?? caretOnceGone(view, {block}, above: backward),
  );
}
