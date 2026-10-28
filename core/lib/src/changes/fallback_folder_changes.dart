import 'folder_changes.dart';

/// Follows [_primary]; once that ends (e.g. watching failed), asks for the
/// folder to be listed again, as changes may have been missed, and goes
/// on with [_fallback].
final class FallbackFolderChanges implements FolderChanges {
  FallbackFolderChanges(this._primary, this._fallback);

  final FolderChanges _primary;
  final FolderChanges _fallback;

  /// Whether the latest listen has gone on with the fallback.
  bool get isOnFallback => _onFallback;
  var _onFallback = false;

  @override
  Stream<ChangeHint> get changes async* {
    _onFallback = false;
    yield* _primary.changes;
    _onFallback = true;
    yield const ListAgain();
    yield* _fallback.changes;
  }
}
