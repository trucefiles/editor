import '../storage/rel_path.dart';

/// Changes to the files in one folder, made by anyone: the sync tool,
/// other apps or this app.
///
/// Gives hints only: which paths changed, where the platform tells, or
/// that the folder should be listed again, where it can't tell (a timer,
/// or after following stopped and changes may have been missed). Whoever
/// listens lists the folder or the hinted paths, and finds what changed.
/// How changes are found, and how an implementation keeps to the files it
/// is told to follow (skipping folders where it can, else dropping the
/// changes of other files), is up to each.
abstract interface class FolderChanges {
  /// Hints that the folder's followed files changed. A path may come more
  /// than once for one change.
  ///
  /// Starts when listened to and stops when cancelled; each listen starts
  /// anew. Ends only if changes can no longer be followed at all; never
  /// emits errors.
  Stream<ChangeHint> get changes;
}

/// What [FolderChanges] tells.
sealed class ChangeHint {
  const ChangeHint();
}

/// The followed file or folder at [path], relative to the folder, was
/// created, changed or deleted.
final class PathChanged extends ChangeHint {
  const PathChanged(this.path);

  final RelPath path;

  @override
  bool operator ==(Object other) => other is PathChanged && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'PathChanged($path)';
}

/// Anything in the folder may have changed: list it again.
final class ListAgain extends ChangeHint {
  const ListAgain();

  @override
  bool operator ==(Object other) => other is ListAgain;

  @override
  int get hashCode => (ListAgain).hashCode;

  @override
  String toString() => 'ListAgain()';
}

/// Narrows [FolderChanges].
extension FolderChangesWithout on FolderChanges {
  /// These changes without the hints of paths [drops] matches.
  FolderChanges without(bool Function(RelPath path) drops) =>
      _Without(this, drops);
}

final class _Without implements FolderChanges {
  const _Without(this._all, this._drops);

  final FolderChanges _all;
  final bool Function(RelPath path) _drops;

  @override
  Stream<ChangeHint> get changes => _all.changes.where(
    (hint) => switch (hint) {
      PathChanged(:final path) => !_drops(path),
      ListAgain() => true,
    },
  );
}
