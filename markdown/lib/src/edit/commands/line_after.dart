import '../../doc/doc_nodes.dart';
import '../../doc/normalized.dart';
import '../../view/rows.dart';
import '../change.dart';
import '../selection.dart';
import 'items.dart';

/// An empty line right after [block] (a divider), as after one
/// character; in an item, a new item after it, with the box Enter would
/// give it. The caret goes into the new line.
Change lineAfter(ViewRows view, NodeId block) {
  final fresh = view.doc.freshIds;
  final text = emptyParagraph(fresh);
  return (
    doc: withBlockAfter(view, block, text, fresh),
    selection: TextSelection.caret(Place(text.id, 0)),
  );
}
