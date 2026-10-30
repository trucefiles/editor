import '../../doc/doc_nodes.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';

/// [block], one without text (a selected divider), gone: the caret at
/// the end of the text above it if [backward], else at the start of the
/// next text, or the other way where there is none. As an item's only
/// block, an empty text takes its place, with the caret, so the item
/// stays as an empty one.
Change removeBlock(ViewRows view, NodeId block, {required bool backward}) {
  if (view.doc.parentOf(block) case ItemNode(children: [_])) {
    final fresh = view.doc.freshIds;
    final text = emptyParagraph(fresh);
    return (
      doc: view.doc.edited({
        block: [text],
      }, fresh: fresh),
      selection: TextSelection.caret(Place(text.id, 0)),
    );
  }
  return (
    doc: view.doc.edited({block: const []}),
    selection: caretOnceGone(view, {block}, above: backward),
  );
}
