import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../folder_state/folder_state_controller.dart';
import '../sync_tool/base_folder_wiring.dart';
import '../versions/compare_controller.dart';

/// What the conflict screen shows.
typedef ConflictState = CompareState<FolderConflict, ConflictSides>;

final conflictProvider = NotifierProvider.autoDispose
    .family<ConflictController, ConflictState, FolderConflict>(
      ConflictController.new,
    );

/// Resolves one document's conflict copies one by one, oldest first;
/// after each keep, goes on to the next copy found after it.
class ConflictController
    extends CompareController<FolderConflict, ConflictSides> {
  ConflictController(super.start);

  @override
  bool get goesOn => true;

  @override
  CompareSource<FolderConflict, ConflictSides> source() => ConflictCompare(
    ref.read(baseFolderServicesProvider(start.folder.base)),
    ref.read(folderContentsProvider.notifier).refresh,
  );

  @override
  DocumentKey get document => start.key;

  @override
  FolderConflict? nextIn(FolderContents contents) =>
      contents.conflicts.forDocument(start.key);
}
