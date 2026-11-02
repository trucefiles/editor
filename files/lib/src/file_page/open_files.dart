import 'package:truce_folders/truce_folders.dart';

/// The files open on screen right now, so that a change to what the
/// app may touch in a base folder first keeps their edits where they last.
final class OpenFiles {
  final _open = <Object, _OpenFile>{};

  /// Adds an open file, now in the base folder [base] gives, whose
  /// edits [secure] keeps; the returned call takes it out again.
  void Function() add({
    required BaseFolder? Function() base,
    required Future<void> Function() secure,
  }) {
    final key = Object();
    _open[key] = (base: base, secure: secure);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every file open in [base].
  Future<void> secureIn(BaseFolder base) => Future.wait([
    for (final open in [..._open.values])
      if (open.base() == base) open.secure(),
  ]);
}

typedef _OpenFile = ({
  BaseFolder? Function() base,
  Future<void> Function() secure,
});
