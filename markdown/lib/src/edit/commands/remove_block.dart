import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../change.dart';

/// [block], one without text (a selected divider), gone; the caret at the
/// start of the next text shown, else at the end of the one above.
Change removeBlock(ViewRows view, NodeId block) => (
  doc: view.doc.edited({block: const []}),
  selection: caretOnceGone(view, {block}),
);
