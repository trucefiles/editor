import 'package:truce_core/truce_core.dart';

/// The files open on screen right now, so that removing a folder first
/// keeps their edits where they last.
final class OpenFiles {
  final _open = <Object, _OpenFile>{};

  /// Adds an open file, now in the folder [folder] gives, whose edits
  /// [secure] keeps by the rule of its reason; the returned call takes it
  /// out again.
  void Function() add({
    required FolderId? Function() folder,
    required Future<void> Function(SecureReason reason) secure,
  }) {
    final key = Object();
    _open[key] = (folder: folder, secure: secure);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every file open in [folder], by the rule of
  /// [reason]: [SecureReason.hide] writes no conflict copy (e.g. before
  /// the user decides), [SecureReason.close] keeps what can't go into the
  /// file as one.
  Future<void> secureIn(FolderId folder, SecureReason reason) => Future.wait([
    for (final open in [..._open.values])
      if (open.folder() == folder) open.secure(reason),
  ]);
}

typedef _OpenFile = ({
  FolderId? Function() folder,
  Future<void> Function(SecureReason reason) secure,
});
