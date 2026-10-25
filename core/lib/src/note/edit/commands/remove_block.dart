import '../../tree/blocks.dart';
import '../commit.dart';
import '../shown/shown_note.dart';
import 'outline.dart';

/// [block], one without text (a selected rule), gone; the caret at the
/// start of the next text shown, else at the end of the one above.
Edit removeBlock(ShownNote note, LeafBlock block) => Edit(
  replaced: {block.id: const []},
  selection: caretOnceGone(note, {block.id}),
);
