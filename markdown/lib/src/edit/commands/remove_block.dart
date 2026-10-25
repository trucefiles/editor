import '../../tree/blocks.dart';
import '../commit.dart';
import '../shown/shown_document.dart';
import 'outline.dart';

/// [block], one without text (a selected rule), gone; the caret at the
/// start of the next text shown, else at the end of the one above.
Edit removeBlock(ShownDocument document, LeafBlock block) => Edit(
  replaced: {block.id: const []},
  selection: caretOnceGone(document, {block.id}),
);
