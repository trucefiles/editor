import '../storage/rel_path.dart';
import 'folder_changes.dart';

/// Follows [_primary]; once that ends (e.g. watching failed), goes on with
/// [_fallback].
final class FallbackFolderChanges implements FolderChanges {
  FallbackFolderChanges(this._primary, this._fallback);

  final FolderChanges _primary;
  final FolderChanges _fallback;

  /// Whether the latest listen has gone on with the fallback.
  bool get isOnFallback => _onFallback;
  var _onFallback = false;

  @override
  Stream<RelPath> get changes async* {
    _onFallback = false;
    yield* _primary.changes;
    _onFallback = true;
    yield* _fallback.changes;
  }
}
