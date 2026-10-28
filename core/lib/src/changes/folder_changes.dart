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
  /// anew. Ends when changes can no longer be followed, e.g. the folder is
  /// gone; never emits errors.
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
