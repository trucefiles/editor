import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import 'split_block.dart';

/// [block], one without text (a selected divider), gone; the caret at the
/// start of the next text shown, else at the end of the one above.
Change removeBlock(ViewRows view, NodeId block) => (
  doc: view.doc.edited({block: const []}),
  selection: caretOnceGone(view, {block}),
);

/// [block], one without text (a selected divider), replaced by [lines]
/// typed over it, as paragraphs; the caret at their end.
Change typedOverBlock(ViewRows view, NodeId block, List<VisibleText> lines) {
  final fresh = view.doc.freshIds;
  final paragraph = ParagraphNode(fresh.take(), VisibleText.empty);
  final doc = view.doc.edited({
    block: [paragraph],
  }, fresh: fresh);
  return splitWith(
    ViewRows(doc, done: view.done),
    Place(paragraph.id, 0),
    lines,
  );
}
