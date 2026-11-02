import 'package:truce_core/truce_core.dart';

/// The files open on screen right now, so that removing a folder first
/// keeps their edits where they last.
final class OpenFiles {
  final _open = <Object, _OpenFile>{};

  /// Adds an open file, now in the folder [folder] gives, whose edits
  /// [secure] keeps; the returned call takes it out again.
  void Function() add({
    required FolderId? Function() folder,
    required Future<void> Function() secure,
  }) {
    final key = Object();
    _open[key] = (folder: folder, secure: secure);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every file open in [folder].
  Future<void> secureIn(FolderId folder) => Future.wait([
    for (final open in [..._open.values])
      if (open.folder() == folder) open.secure(),
  ]);
}

typedef _OpenFile = ({
  FolderId? Function() folder,
  Future<void> Function() secure,
});
