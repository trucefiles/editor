import 'package:truce_core/truce_core.dart' show Version;

import '../edit/shown/selection.dart';
import '../edit/shown/shown_document.dart';
import '../tree/blocks.dart';

/// The editor owner's own bookkeeping, which its users never read.
final class EditorWork {
  const EditorWork({
    required this.lineage,
    this.rev = 0,
    this.holds = const Holds(),
    this.undo,
    this.nextId = 0,
  });

  /// The file version the text descends from; `null` for a new document.
  /// Moves only with a change elsewhere or a pick taken.
  final Version? lineage;

  /// Counts the text changes commands made.
  final int rev;

  /// Toggled items whose move waits for the toggle to settle.
  final Holds holds;

  /// The undo of the last removal, while it can be made.
  final Removal? undo;

  final int nextId;

  EditorWork copyWith({
    Object? lineage = _same,
    int? rev,
    Holds? holds,
    Object? undo = _same,
    int? nextId,
  }) => EditorWork(
    lineage: identical(lineage, _same) ? this.lineage : lineage as Version?,
    rev: rev ?? this.rev,
    holds: holds ?? this.holds,
    undo: identical(undo, _same) ? this.undo : undo as Removal?,
    nextId: nextId ?? this.nextId,
  );
}

/// Marks an [EditorWork.copyWith] field left as it is.
const _same = Object();

/// Toggled items waiting to settle, each with the box it had before;
/// [timer] the settle timer running, `null` once it fired.
final class Holds {
  const Holds({this.items = const {}, this.timer});

  final Map<BlockId, bool> items;
  final int? timer;

  bool get isEmpty => items.isEmpty;
}

/// How to undo removal [id]: the document before it, valid at [rev].
typedef Removal = ({
  int id,
  ShownDocument before,
  Selection selection,
  int rev,
});
