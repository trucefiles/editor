import 'dart:async';

import 'package:truce_core/truce_core.dart';

import '../base_folder.dart';
import '../document_folder.dart';
import '../folder_list_owner.dart';
import '../folder_lookup.dart';
import 'base_folder_services.dart';
import 'sync_tools.dart';

/// Builds the services of [base] on [place], its sync tool's access to it,
/// telling [reach] how each access goes, bounded to [selection].
typedef BuildServices = BaseFolderServices Function(
  BaseFolder base,
  ToolPlace place,
  FolderReach reach,
  Selection selection,
);

/// The stack of each base folder the folder list shows: its sync tool's
/// place, its reach, and its services bounded to what its folders show.
/// Follows the folder list owner's state: a base folder's stack is built
/// when a folder first shows it, its services are built again when what
/// its folders show changes (place and reach stay, so a write still under
/// way in the old services keeps its files), and it goes with its last
/// folder.
///
/// A base folder no folder shows (any more) keeps services that touch
/// nothing: whoever still holds it, e.g. a screen about to close, gets
/// [StoreError.outside].
final class BaseFolderStacks {
  BaseFolderStacks(
    this._folders, {
    required this._tools,
    required this._build,
  }) {
    _listening = _folders.changes.listen((_) => _follow());
    _follow();
  }

  final FolderListOwner _folders;
  final SyncTools _tools;
  final BuildServices _build;
  late final StreamSubscription<FolderListState> _listening;

  /// The stacks of the base folders the list shows, by id.
  final _shown = <String, _Stack>{};

  /// Services that touch nothing, of base folders no folder shows, by id.
  /// Kept until the app ends: one per base folder the user removed.
  final _gone = <String, BaseFolderServices>{};

  /// The list [_shown] was last built for.
  List<DocumentFolder>? _followed;

  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires each time services are built or retired.
  Stream<void> get changes => _changes.stream;

  /// The services of [base]: as its folders show it now.
  BaseFolderServices servicesOf(BaseFolder base) {
    _follow();
    return _shown[base.id]?.services ??
        _gone.putIfAbsent(base.id, () {
          final place = _placeOf(base);
          return _retired(base, place, folderReach(place.files));
        });
  }

  /// The services of the base folder with [id], one the list shows or
  /// showed.
  BaseFolderServices servicesOfId(String id) {
    _follow();
    return _shown[id]?.services ??
        _gone[id] ??
        (throw StateError('No base folder $id'));
  }

  /// What each base folder the list shows selects, by id.
  Map<String, Selection> get selections {
    _follow();
    return {
      for (final MapEntry(:key, :value) in _shown.entries) key: value.selection,
    };
  }

  /// The place of [base] by its sync tool, e.g. to pick subfolders; a
  /// base folder not added yet gets one for this look only.
  ToolPlace placeOf(BaseFolder base) {
    _follow();
    return _shown[base.id]?.place ?? _placeOf(base);
  }

  /// Ends every reach; the services stay as they are.
  Future<void> close() async {
    await _listening.cancel();
    await Future.wait([for (final stack in _shown.values) stack.reach.close()]);
    await _changes.close();
  }

  /// Builds the stacks for the list the owner shows now, unless done.
  /// Run at every change, and before every answer, so no answer is ever
  /// older than the list, whoever heard of the change first.
  void _follow() {
    final folders = switch (_folders.state) {
      FoldersLoaded(:final folders) => folders,
      FoldersLoading() || FoldersUnreadable() => const <DocumentFolder>[],
    };
    if (identical(folders, _followed)) return;
    _followed = folders;
    final bases = {for (final folder in folders) folder.base.id: folder.base};
    final goneIds = [
      for (final id in _shown.keys)
        if (!bases.containsKey(id)) id,
    ];
    var changed = goneIds.isNotEmpty;
    for (final id in goneIds) {
      final stack = _shown.remove(id)!;
      _gone[id] = _retired(stack.base, stack.place, stack.reach);
    }
    for (final base in bases.values) {
      final selection = folders.selectionOf(base);
      final stack = _shown[base.id];
      if (stack != null && stack.selection == selection) continue;
      changed = true;
      _gone.remove(base.id);
      final place = stack?.place ?? _placeOf(base);
      final reach = stack?.reach ?? folderReach(place.files);
      _shown[base.id] = (
        base: base,
        place: place,
        reach: reach,
        selection: selection,
        services: _build(base, place, reach, selection),
      );
    }
    if (changed && !_changes.isClosed) _changes.add(null);
  }

  ToolPlace _placeOf(BaseFolder base) =>
      _tools.of(base.toolId).place(base.address);

  /// [base]'s services over [place] that touch nothing, with [reach]
  /// ended.
  BaseFolderServices _retired(
    BaseFolder base,
    ToolPlace place,
    FolderReach reach,
  ) {
    unawaited(reach.close());
    return _build(base, place, reach, Selection.nothing);
  }
}

typedef _Stack = ({
  BaseFolder base,
  ToolPlace place,
  FolderReach reach,
  Selection selection,
  BaseFolderServices services,
});
