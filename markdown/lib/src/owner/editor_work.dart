import 'package:truce_core/truce_core.dart' show Version;

import '../doc/doc_tree.dart';
import '../doc/origin.dart';
import '../edit/selection.dart';
import '../print/printer.dart';
import 'save_clock.dart';

/// The editor owner's own bookkeeping, which its users never read.
final class EditorWork {
  const EditorWork({
    required this.origin,
    required this.lineage,
    this.rev = 0,
    this.sentRev = 0,
    this.picks = 0,
    this.clock = const SaveClock(),
    this.undo,
    this.nextUndo = 0,
    this.left,
  });

  /// Where the doc tree was read from.
  final Origin origin;

  /// The file version the text descends from; `null` for a new document.
  /// Moves only with a change elsewhere or a pick taken.
  final Version? lineage;

  /// Counts the text changes, going on from a pick's.
  final int rev;

  /// The rev of the text last sent to the file owner.
  final int sentRev;

  /// Counts the picks taken.
  final int picks;

  final SaveClock clock;

  /// The undo of the last removal, while it can be made.
  final Removal? undo;

  final int nextUndo;

  /// Visual edit as Markdown edit left it: its print and selection, which
  /// the caret goes back by.
  final Left? left;

  EditorWork copyWith({
    Origin? origin,
    Object? lineage = _same,
    int? rev,
    int? sentRev,
    int? picks,
    SaveClock? clock,
    Object? undo = _same,
    int? nextUndo,
    Object? left = _same,
  }) => EditorWork(
    origin: origin ?? this.origin,
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    rev: rev ?? this.rev,
    sentRev: sentRev ?? this.sentRev,
    picks: picks ?? this.picks,
    clock: clock ?? this.clock,
    undo: identical(undo, _same) ? this.undo : undo as Removal?,
    nextUndo: nextUndo ?? this.nextUndo,
    left: identical(left, _same) ? this.left : left as Left?,
  );
}

/// Marks an [EditorWork.copyWith] field left as it is.
const _same = Object();

/// How to undo removal [id]: the document before it, valid at [rev].
typedef Removal = ({int id, DocTree before, Selection selection, int rev});

/// Visual edit when Markdown edit took over: its [printed] text and its
/// [selection].
typedef Left = ({PrintedMarkdown printed, Selection selection});
