import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/documents_owner.dart';
import '../file_types/document_types.dart';
import '../folders/base_folder.dart';
import '../folders/folder_lookup.dart';
import '../folders/folders_controller.dart';
import '../sync_tool/app_writes.dart';
import '../sync_tool/base_folder_services.dart';
import 'folder_contents.dart';

/// The app's folder state owner, wired: it lists the base folders of the
/// added folders, by their sync tools, the first time once the edits left
/// by the last run are in their files (so no document shows its old text
/// while its draft is pending), and again whenever what a base folder's
/// folders select changes.
final folderStateOwnerProvider = Provider<FolderStateOwner>((ref) {
  var bases = <String, BaseFolder>{};
  final owner = folderStateOwner((baseId) {
    final services = ref.read(baseFolderServicesProvider(bases[baseId]!));
    return (scanner: services.scanner, marks: services.marks);
  });
  final writes = ref.read(appWritesProvider).all.listen(owner.send);
  ref.onDispose(() {
    unawaited(writes.cancel());
    unawaited(owner.close());
  });
  unawaited(
    ref.read(documentsProvider).draftsRecovered.then((_) {
      if (!ref.mounted) return;
      ref.listen(loadedFoldersProvider, (_, folders) {
        if (folders.value case final folders?) {
          // Every base folder a listing may still ask for stays known.
          bases = {
            ...bases,
            for (final folder in folders) folder.base.id: folder.base,
          };
          owner.send(
            BasesChanged({
              for (final base in {for (final folder in folders) folder.base})
                base.id: folders.selectionOf(base),
            }),
          );
        }
      }, fireImmediately: true);
    }),
  );
  return owner;
});

final folderContentsProvider =
    AsyncNotifierProvider<FolderStateController, FolderContents>(
      FolderStateController.new,
    );

/// What the added folders hold, for the screens: changes from the sync
/// tool, other editors or the app's own writes show up as the folder
/// state owner finds them.
class FolderStateController extends AsyncNotifier<FolderContents> {
  /// What [FolderState] holds, as this build's folders show it.
  FolderContents Function(FolderState state)? _contentsOf;

  @override
  Future<FolderContents> build() async {
    final owner = ref.watch(folderStateOwnerProvider);
    final folders = await ref.watch(loadedFoldersProvider.future);
    final types = ref.watch(documentTypesProvider);
    FolderContents contentsOf(FolderState state) =>
        FolderContents(state, folders: folders, types: types);
    _contentsOf = contentsOf;
    final changes = owner.changes.listen((state) {
      final contents = contentsOf(state);
      if (contents.loaded) this.state = AsyncData(contents);
    });
    ref.onDispose(() => unawaited(changes.cancel()));
    if (contentsOf(owner.state) case final contents when contents.loaded) {
      return contents;
    }
    return owner.changes
        .map(contentsOf)
        .firstWhere((contents) => contents.loaded);
  }

  /// Lists every base folder again now, e.g. when a document opens, when
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
