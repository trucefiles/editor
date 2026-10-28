import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import '../sync_tool/base_folder_services.dart';
import '../versions/version_text.dart';

/// The two versions of one conflict copy, as text to compare.
final class ConflictSides {
  const ConflictSides({
    required this.copy,
    required this.current,
    required this.other,
  });

  /// The copy being resolved: the oldest one left.
  final ConflictCopy copy;

  /// The main file's text; `null` if it was deleted.
  final String? current;

  final String other;

  /// Reads both sides of [conflict]'s oldest copy, as [versionText].
  static Future<Result<ConflictSides, StoreError>> load(
    BaseFolderServices services,
    Conflict conflict,
  ) async {
    final copy = conflict.copies.first;
    final Uint8List other;
    switch (await services.conflicts.readCopy(copy)) {
      case Ok(:final value):
        other = value;
      case Err(:final error):
        return Err(error);
    }
    String? current;
    if (!conflict.isOrphaned) {
      switch (await services.conflicts.readMain(conflict)) {
        case Ok(:final value):
          current = versionText(value);
        case Err(:final error):
          return Err(error);
      }
    }
    return Ok(
      ConflictSides(copy: copy, current: current, other: versionText(other)),
    );
  }
}
