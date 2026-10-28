import 'package:truce_core/truce_core.dart' show EditorBook;

import '../doc/origin.dart';
import '../edit/selection.dart';
import '../print/printer.dart';
import '../view/rows.dart';
import 'history/snapshot.dart';

/// The editor owner's own bookkeeping, which its users never read.
final class EditorWork {
  const EditorWork({required this.origin, required this.book, this.left});

  /// Where the doc tree was read from.
  final Origin origin;

  /// The edits on their way to the file owner, and the undo history.
  final EditorBook<Snapshot> book;

  /// Visual edit as Markdown edit left it: what showed, its print and
  /// selection, which Visual edit comes back by.
  final Left? left;

  EditorWork copyWith({
    Origin? origin,
    EditorBook<Snapshot>? book,
    Object? left = _same,
  }) => EditorWork(
    origin: origin ?? this.origin,
    book: book ?? this.book,
    left: identical(left, _same) ? this.left : left as Left?,
  );
}

/// Marks an [EditorWork.copyWith] field left as it is.
const _same = Object();

/// What Visual edit showed, as [view] with [selection], printed as
/// [printed]: before a reload, or when Markdown edit took over.
typedef Left = ({ViewRows view, Selection selection, PrintedMarkdown printed});
