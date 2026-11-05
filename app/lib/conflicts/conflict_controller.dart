import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../file_types/file_types.dart';
import '../folder_state/folder_state_controller.dart';
import '../folders/open_folders_wiring.dart';
import '../versions/compare_controller.dart';

/// What the conflict screen shows.
typedef ConflictState = CompareState<FolderConflict, ConflictSides>;

final conflictProvider = NotifierProvider.autoDispose
    .family<ConflictController, ConflictState, FolderConflict>(
      ConflictController.new,
    );

/// Resolves one file's conflict copies one by one, oldest first;
/// after each keep, goes on to the next copy found after it.
class ConflictController
    extends CompareController<FolderConflict, ConflictSides> {
  ConflictController(super.start);

  @override
  bool get goesOn => true;

  @override
  CompareSource<FolderConflict, ConflictSides> source() => ConflictCompare(
    ref.read(folderServicesProvider(start.folder.id)),
    ref.read(folderContentsProvider.notifier).refresh,
    merge: ref.read(fileTypesProvider).mergeOf(start.conflict.mainPath),
  );

  @override
  FileKey get file => start.key;

  @override
  FolderConflict? nextIn(FolderContents contents) =>
      contents.shown.conflicts.forFile(start.key);
}
