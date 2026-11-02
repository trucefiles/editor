import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../versions/version_text.dart';

/// Both versions of a conflict merged into one by the document's type:
/// the main file's [bytes] to keep ([KeepMerged]), and what of the copy
/// lost to the main file ([MergedText.lost]).
typedef MergedSides = ({Uint8List bytes, List<String> lost});

/// The two versions of one conflict copy, as text to compare, and both
/// merged where the document's type merges them.
final class ConflictSides {
  const ConflictSides({
    required this.copy,
    required this.current,
    required this.other,
    this.merged,
  });

  /// The copy being resolved: the oldest one left.
  final ConflictCopy copy;

  /// The main file's text; `null` if it was deleted.
  final String? current;

  final String other;

  /// Both merged; `null` if the type doesn't merge, the main file is
  /// gone, or the two can't be merged.
  final MergedSides? merged;

  /// Reads both sides of [conflict]'s oldest copy, as [versionText], and
  /// merges them by [merge] if given.
  static Future<Result<ConflictSides, StoreError>> load(
    BaseFolderServices services,
    Conflict conflict, {
    TextMerge? merge,
  }) async {
    final copy = conflict.copies.first;
    final Uint8List other;
    switch (await services.conflicts.readCopy(copy)) {
      case Ok(:final value):
        other = value;
      case Err(:final error):
        return Err(error);
    }
    Uint8List? current;
    if (!conflict.isOrphaned) {
      switch (await services.conflicts.readMain(conflict)) {
        case Ok(:final value):
          current = value;
        case Err(:final error):
          return Err(error);
      }
    }
    return Ok(
      ConflictSides(
        copy: copy,
        current: current == null ? null : versionText(current),
        other: versionText(other),
        merged: switch ((merge, current)) {
          (final merge?, final current?) => _merged(merge, current, other),
          _ => null,
        },
      ),
    );
  }

  /// [other] merged into [current] by [merge], in [current]'s byte style;
  /// `null` if either is no text or they can't be merged.
  static MergedSides? _merged(
    TextMerge merge,
    Uint8List current,
    Uint8List other,
  ) {
    final (main, copy) = (TextFile.decode(current), TextFile.decode(other));
    if (main == null || copy == null) return null;
    return switch (merge.merge(main.text, copy.text)) {
      MergedText(:final text, :final lost) => (
        bytes: main.encode(text),
        lost: lost,
      ),
      CantMerge() => null,
    };
  }
}
