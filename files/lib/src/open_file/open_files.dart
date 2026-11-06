import 'package:truce_core/truce_core.dart';

/// The files open on screen right now, so that removing a folder or
/// ending the app first keeps their edits where they last.
final class OpenFiles {
  final _open = <Object, _OpenFile>{};

  /// Adds an open file, now in the folder [folder] gives, whose edits
  /// [secure] keeps by the rule of its reason, and [secureForExit] keeps
  /// as the app ends, waiting for its file at most as long as it is
  /// given; the returned call takes it out again.
  void Function() add({
    required FolderId? Function() folder,
    required Future<void> Function(SecureReason reason) secure,
    required Future<void> Function({required Duration within}) secureForExit,
  }) {
    final key = Object();
    _open[key] = (folder: folder, secure: secure, secureForExit: secureForExit);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every file open in [folder], by the rule of
  /// [reason]: [SecureReason.hide] writes no conflict copy (e.g. before
  /// the user decides), [SecureReason.close] keeps what can't go into the
  /// file as one.
  Future<void> secureIn(FolderId folder, SecureReason reason) =>
      _all((file) => file.folder() == folder, (file) => file.secure(reason));

  /// Keeps the edits of every open file as the app ends (on the device
  /// at least), then waits until their files hold them, as far as they
  /// can now; all within [within].
  Future<void> secureForExit({required Duration within}) =>
      _all((_) => true, (file) => file.secureForExit(within: within));

  /// Runs [run] on every open file [where] holds, all at once.
  Future<void> _all(
    bool Function(_OpenFile file) where,
    Future<void> Function(_OpenFile file) run,
  ) async {
    await Future.wait([
      for (final file in [..._open.values])
        if (where(file)) run(file),
    ]);
  }
}

typedef _OpenFile = ({
  FolderId? Function() folder,
  Future<void> Function(SecureReason reason) secure,
  Future<void> Function({required Duration within}) secureForExit,
});
