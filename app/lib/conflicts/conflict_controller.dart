import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../scan/folder_scans.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
import '../versions/compare_controller.dart';
import 'conflict_compare.dart';
import 'conflict_sides.dart';
import 'folder_conflicts.dart';

/// What the conflict screen shows.
typedef ConflictState = CompareState<FolderConflict, ConflictSides>;

final conflictProvider = NotifierProvider.autoDispose
    .family<ConflictController, ConflictState, FolderConflict>(
      ConflictController.new,
    );

/// Resolves one document's conflict copies one by one, oldest first;
/// after each keep, goes on to the next copy a later scan finds.
class ConflictController
    extends CompareController<FolderConflict, ConflictSides> {
  ConflictController(super.start);

  @override
  bool get goesOn => true;

  @override
  CompareSource<FolderConflict, ConflictSides> source() => ConflictCompare(
    ref.read(folderServicesProvider(start.folder.location)),
    ref.read(folderScansProvider.notifier).refresh,
  );

  @override
  FolderConflict? nextIn(FolderScans scans) =>
      scans.conflicts.forNote(start.key);
}
