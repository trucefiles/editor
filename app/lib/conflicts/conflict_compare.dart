import 'package:truce_core/truce_core.dart';

import '../sync_tool/base_folder_services.dart';
import 'conflict_sides.dart';
import 'folder_conflicts.dart';

/// Compares a document with its oldest conflict copy, in the folder of
/// [_services]; [_rescan] scans after a keep.
final class ConflictCompare
    implements CompareSource<FolderConflict, ConflictSides> {
  ConflictCompare(this._services, this._rescan);

  final BaseFolderServices _services;
  final Future<void> Function() _rescan;

  @override
  Future<Result<ConflictSides, StoreError>> load(FolderConflict target) =>
      ConflictSides.load(_services, target.conflict);

  @override
  Future<Result<void, ResolveError>> keep(
    FolderConflict target,
    ConflictSides sides,
    Resolution choice,
  ) => _services.conflicts.resolve(target.conflict, sides.copy, choice);

  @override
  Future<void> rescan() => _rescan();
}
