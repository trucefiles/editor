import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';

/// The id of the node showing [entry]: the one scheme of node ids. It
/// stays while the entry's first line does, so the caret stays on it.
String nodeIdOf(DisplayEntry entry) => switch (entry) {
  LeafEntry(:final leaf) => 'leaf-$leaf',
  LineEntry(:final line) => 'line-$line',
  TableEntry(:final leaf) => 'table-$leaf',
  DoneHeadingEntry(:final list) => 'done-$list',
  AddItemEntry(:final list) => 'add-$list',
};

/// The node showing [entry] of [document]; [view] shows its text, if it
/// has any.
DocumentNode nodeOf(
  DisplayEntry entry,
  EditView? view,
  MarkdownDocument document,
) {
  final id = nodeIdOf(entry);
  return switch ((entry, view)) {
    (TableEntry(:final leaf), final LeafView view) => DrawnTableNode(
      id,
      document.leafById(leaf)! as TableBlock,
      frames: view.frames,
    ),
    (final DoneHeadingEntry heading, _) => DoneHeadingNode(id, heading),
    (final AddItemEntry button, _) => AddItemNode(id, button),
    (_, final view?) => ParagraphNode(
      id: id,
      text: AttributedText(view.text),
      metadata: {framesKey: framesOf(view)},
    ),
    _ => throw ArgumentError.value(entry, 'entry', 'shows no text'),
  };
}

/// The frames [view] shows inside: none for a line as it is in the file.
List<Frame> framesOf(EditView view) => switch (view) {
  LeafView(:final frames) => frames,
  RawLineView() => const [],
};

/// The metadata key of the frames a text node shows inside (see
/// [framesOf]).
const framesKey = 'frames';
