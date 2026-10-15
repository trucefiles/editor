import '../storage/rel_path.dart';
import 'folder_changes.dart';

/// Follows [_primary]; once that ends (e.g. watching failed), goes on with
/// [_fallback].
final class FallbackFolderChanges implements FolderChanges {
  const FallbackFolderChanges(this._primary, this._fallback);

  final FolderChanges _primary;
  final FolderChanges _fallback;

  @override
  Stream<RelPath> get changes async* {
    yield* _primary.changes;
    yield* _fallback.changes;
  }
}
