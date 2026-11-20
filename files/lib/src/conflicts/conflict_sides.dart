import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import '../file_merge.dart';

/// The two versions of one conflict copy, as bytes each type shows its
/// own way, and both merged where the file's type merges them.
final class ConflictSides {
  const ConflictSides({
    required this.copy,
    required this.current,
    required this.other,
    this.merged,
  });

  /// The copy being resolved: the oldest one left.
  final ConflictCopy copy;

  /// The main file's bytes; `null` if it was deleted.
  final Uint8List? current;

  final Uint8List other;

  /// Both merged; `null` if the type doesn't merge, the main file is
  /// gone, or the two can't be merged.
  final MergedSides? merged;

  /// Reads both sides of [conflict]'s oldest copy, and merges them by
  /// [merge] if given.
  static Future<Result<ConflictSides, StoreError>> load(
    FolderServices services,
    Conflict conflict, {
    FileMerge? merge,
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
        current: current,
        other: other,
        merged: switch ((merge, current)) {
          (final merge?, final current?) => merge.merge(current, other),
          _ => null,
        },
      ),
    );
  }
}
