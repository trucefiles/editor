import '../../doc/doc_nodes.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';

/// [block], one without text (a divider), replaced by an empty line, as
/// one selected character is by Enter; in an item it stays in the item,
/// which keeps its box. The caret goes into the new line.
Change lineInPlace(ViewRows view, NodeId block) {
  final fresh = view.doc.freshIds;
  final text = emptyParagraph(fresh);
  return (
    doc: view.doc.edited({
      block: [text],
    }, fresh: fresh),
    caret: CaretAt(TextSelection.caret(Place(text.id, 0))),
  );
}
