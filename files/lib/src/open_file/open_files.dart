import 'package:truce_core/truce_core.dart';

/// The files open on screen right now, so that removing a folder or
/// ending the app first keeps their edits where they last.
final class OpenFiles {
  final _open = <Object, _OpenFile>{};

  /// Adds an open file, now in the folder [folder] gives, whose edits
  /// [secure] keeps by the rule of its reason, and [written] completes
  /// once its file owner writes no more for now; the returned call takes
  /// it out again.
  void Function() add({
    required FolderId? Function() folder,
    required Future<void> Function(SecureReason reason) secure,
    required Future<void> Function() written,
  }) {
    final key = Object();
    _open[key] = (folder: folder, secure: secure, written: written);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every file open in [folder], by the rule of
  /// [reason]: [SecureReason.hide] writes no conflict copy (e.g. before
  /// the user decides), [SecureReason.close] keeps what can't go into the
  /// file as one.
  Future<void> secureIn(FolderId folder, SecureReason reason) => _all(
    (open) => open.folder() == folder,
    open: (file) => file.secure(reason),
  );

  /// Keeps the edits of every open file as the app ends
  /// ([SecureReason.exit]: on the device at least), then waits until
  /// their files hold them, as far as they can now.
  Future<void> secureForExit() => _all(
    (_) => true,
    open: (file) async {
      await file.secure(SecureReason.exit);
      await file.written();
    },
  );

  /// Runs [open] on every open file [where] holds, all at once.
  Future<void> _all(
    bool Function(_OpenFile file) where, {
    required Future<void> Function(_OpenFile file) open,
  }) => Future.wait([
    for (final file in [..._open.values])
      if (where(file)) open(file),
  ]);
}

typedef _OpenFile = ({
  FolderId? Function() folder,
  Future<void> Function(SecureReason reason) secure,
  Future<void> Function() written,
});
