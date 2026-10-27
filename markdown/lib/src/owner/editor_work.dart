import 'package:truce_core/truce_core.dart' show Version;

import '../doc/origin.dart';
import '../edit/selection.dart';
import '../print/printer.dart';
import '../view/rows.dart';
import 'history/edit_history.dart';
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
    this.history = const EditHistory(),
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

  /// The undo and redo steps of this editing session.
  final EditHistory history;

  /// Visual edit as Markdown edit left it: what showed, its print and
  /// selection, which Visual edit comes back by.
  final Left? left;

  EditorWork copyWith({
    Origin? origin,
    Object? lineage = _same,
    int? rev,
    int? sentRev,
    int? picks,
    SaveClock? clock,
    EditHistory? history,
    Object? left = _same,
  }) => EditorWork(
    origin: origin ?? this.origin,
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    rev: rev ?? this.rev,
    sentRev: sentRev ?? this.sentRev,
    picks: picks ?? this.picks,
    clock: clock ?? this.clock,
    history: history ?? this.history,
    left: identical(left, _same) ? this.left : left as Left?,
  );
}

/// Marks an [EditorWork.copyWith] field left as it is.
const _same = Object();

/// What Visual edit showed, as [view] with [selection], printed as
/// [printed]: before a reload, or when Markdown edit took over.
typedef Left = ({ViewRows view, Selection selection, PrintedMarkdown printed});
