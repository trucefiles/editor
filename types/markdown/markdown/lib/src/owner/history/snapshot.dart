import '../../doc/doc_tree.dart';
import '../../doc/origin.dart';
import '../../edit/selection.dart';
import '../../print/printer.dart';
import '../editor_contract.dart';
import '../raw_closed.dart';

/// The document as it was at one point of the editing session, to come
/// back to by undo or redo.
sealed class Snapshot {
  const Snapshot();

  /// The text it prints as.
  String get text;
}

/// The doc tree as Visual edit or Read showed it, read from [origin],
/// with [selection]. Its nodes are the very ones shown then, so it
/// prints as it did: blocks never edited keep their bytes.
final class TreeSnapshot extends Snapshot {
  TreeSnapshot(this.doc, this.origin, this.selection);

  final DocTree doc;
  final Origin origin;
  final Selection selection;

  late final PrintedMarkdown printed = printMarkdown(doc, origin);

  @override
  String get text => printed.text;
}

/// The text as Markdown edit showed it.
final class TextSnapshot extends Snapshot {
  const TextSnapshot(this.text);

  @override
  final String text;
}

/// What [content], read from [origin], shows now; an open raw block
/// counts with the text typed in it.
Snapshot snapshotOf(EditorContent content, Origin origin) => switch (content) {
  FormattedContent(:final selection) => switch (rawClosed(content, selection)) {
    (:final doc, :final selection) => TreeSnapshot(doc, origin, selection),
  },
  MarkdownContent(:final text) => TextSnapshot(text),
};
