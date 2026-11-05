import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../file_types/file_types.dart';
import '../folders/folders_controller.dart';
import 'folder_state_wiring.dart';

final folderContentsProvider =
    AsyncNotifierProvider<FolderStateController, FolderContents>(
      FolderStateController.new,
    );

/// What the screens show of the added folders: a new value only when
/// what they hold changed, not with each listing that found the same.
final folderFilesProvider = Provider<FolderFiles?>(
  (ref) => ref.watch(folderContentsProvider.select((c) => c.value?.shown)),
);

/// As [folderFilesProvider], once the folders were listed: for work that
/// waits for them.
final loadedFolderFiles = folderContentsProvider.selectAsync((c) => c.shown);

/// What the added folders hold and when it was seen: changes from the sync
/// tool, other editors or the app's own writes show up as the folder
/// state owner finds them.
class FolderStateController extends AsyncNotifier<FolderContents> {
  /// What [FolderState] holds, as this build's folders show it.
  FolderContents Function(FolderState state)? _contentsOf;

  @override
  Future<FolderContents> build() async {
    final owner = ref.watch(folderStateOwnerProvider);
    ref.watch(folderListingProvider);
    final folders = await ref.watch(foldersProvider.future);
    final types = ref.watch(fileTypesProvider);
    FolderContents? last;
    FolderContents contentsOf(FolderState state) => last = FolderContents(
      state,
      folders: folders,
      types: types,
      before: last,
    );
    _contentsOf = contentsOf;
    final changes = owner.changes.listen((state) {
      final contents = contentsOf(state);
      if (contents.shown.loaded) this.state = AsyncData(contents);
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    if (contentsOf(owner.state) case final contents
        when contents.shown.loaded) {
      return contents;
    }
    return owner.changes
        .map(contentsOf)
        .firstWhere((contents) => contents.shown.loaded);
  }

  /// Lists every folder again now, e.g. when a file closes, when
  /// the app comes back to the foreground, or when the user asks; done
  /// once a listing of each that started after this call has ended, so it
  /// shows every write made before. Waits for the first folders, so it
  /// never lists too few. What the folders hold then; `null` once the app
  /// ends.
  Future<FolderContents?> refresh() async {
    if (!ref.mounted) return null;
    final owner = ref.read(folderStateOwnerProvider);
    await ask<FolderStateInput, Fresh>(owner.send, owner.events, Refresh.new);
    if (!ref.mounted) return null;
    await future;
    return _contentsOf?.call(owner.state);
  }
}
