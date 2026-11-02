import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

import 'conflict_sides.dart';
import 'folder_conflicts.dart';

/// Compares a document with its oldest conflict copy, in the folder of
/// [_services], merged by [_merge] where the document's type merges;
/// [_rescan] scans after a keep.
final class ConflictCompare
    implements CompareSource<FolderConflict, ConflictSides> {
  ConflictCompare(this._services, this._rescan, {this._merge});

  final BaseFolderServices _services;
  final Future<void> Function() _rescan;
  final TextMerge? _merge;

  @override
  Future<Result<ConflictSides, StoreError>> load(FolderConflict target) =>
      ConflictSides.load(_services, target.conflict, merge: _merge);

  @override
  Future<Result<void, ResolveError>> keep(
    FolderConflict target,
    ConflictSides sides,
    Resolution choice,
  ) => _services.conflicts.resolve(target.conflict, sides.copy, choice);

  @override
  Future<void> rescan() => _rescan();
}
