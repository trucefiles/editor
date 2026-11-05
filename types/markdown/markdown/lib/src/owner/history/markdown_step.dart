import 'package:truce_core/truce_core.dart'
    show ShownStep, TextStep, UndoableEdit;

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../doc/origin.dart';
import '../../edit/selection.dart';
import '../../print/printer.dart';
import '../editor_contract.dart';
import '../raw_closed.dart';

/// One edit of a Markdown document, kept to take back by undo and make
/// again by redo.
sealed class MarkdownStep implements UndoableEdit<MarkdownStep> {
  const MarkdownStep();
}

/// An edit in Visual edit: what showed before and after it.
final class TreeStep extends MarkdownStep {
  const TreeStep(this.sides);

  final ShownStep<TreeSide> sides;

  @override
  MarkdownStep joined(MarkdownStep next) => switch (next) {
    TreeStep(:final sides) => TreeStep(this.sides.joined(sides)),
    TextChangeStep() => throw StateError('typing ran across modes'),
  };
}

/// An edit in Markdown edit: the change to its text alone.
final class TextChangeStep extends MarkdownStep {
  const TextChangeStep(this.step);

  final TextStep step;

  @override
  MarkdownStep joined(MarkdownStep next) => switch (next) {
    TextChangeStep(:final step) => TextChangeStep(this.step.joined(step)),
    TreeStep() => throw StateError('typing ran across modes'),
  };
}

/// What Visual edit showed on one side of an edit, read from [origin],
/// and the row the edit shows at. An open raw block counts with the text
/// typed in it, closed only once the side is shown, so keeping a side
/// while typing costs nothing.
final class TreeSide {
  TreeSide(this._shown, this.origin, {this.at});

  final FormattedContent _shown;
  final Origin origin;

  /// The leaf of the row the edit acted at, if known.
  final NodeId? at;

  late final ({DocTree doc, Selection? selection}) _closed = rawClosed(
    _shown,
    _shown.selection,
  );

  /// The doc tree. Its nodes are the very ones shown then, so it prints
  /// as it did: blocks never edited keep their bytes.
  DocTree get doc => _closed.doc;

  Selection? get selection => _closed.selection;

  late final PrintedMarkdown printed = printMarkdown(doc, origin);

  /// The leaf of the row the edit shows at: where it acted, else where
  /// the selection is; `null` if neither is known.
  NodeId? get row => at ?? selection?.endLeaf;
}
