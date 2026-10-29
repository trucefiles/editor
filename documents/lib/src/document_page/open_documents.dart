import 'package:truce_folders/truce_folders.dart';

/// The documents open on screen right now, so that a change to what the
/// app may touch in a base folder first keeps their edits where they last.
final class OpenDocuments {
  final _open = <Object, _OpenDocument>{};

  /// Adds an open document, now in the base folder [base] gives, whose
  /// edits [secure] keeps; the returned call takes it out again.
  void Function() add({
    required BaseFolder? Function() base,
    required Future<void> Function() secure,
  }) {
    final key = Object();
    _open[key] = (base: base, secure: secure);
    return () => _open.remove(key);
  }

  /// Keeps the edits of every document open in [base].
  Future<void> secureIn(BaseFolder base) => Future.wait([
    for (final open in [..._open.values])
      if (open.base() == base) open.secure(),
  ]);
}

typedef _OpenDocument = ({
  BaseFolder? Function() base,
  Future<void> Function() secure,
});
