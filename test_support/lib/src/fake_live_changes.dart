import 'dart:async';

import 'package:truce_core/truce_core.dart';

/// [LiveChanges] driven by the test: [hint] and [end] act on the follows
/// of one folder (`null`: the whole base folder) open right now.
final class FakeLiveChanges implements LiveChanges {
  final _follows = <RelPath?, List<StreamController<ChangeHint>>>{};

  /// The folders asked for, in order, once per follow.
  final List<RelPath?> followed = [];

  /// Folders whose follows end at once, as if gone.
  final Set<RelPath?> missing = {};

  @override
  Stream<ChangeHint> below(RelPath? folder) {
    followed.add(folder);
    final follow = StreamController<ChangeHint>();
    if (missing.contains(folder)) {
      unawaited(follow.close());
    } else {
      (_follows[folder] ??= []).add(follow);
      follow.onCancel = () => _follows[folder]?.remove(follow);
    }
    return follow.stream;
  }

  /// Whether [folder] is followed now.
  bool follows(RelPath? folder) => _follows[folder]?.isNotEmpty ?? false;

  void hint(RelPath? folder, ChangeHint hint) {
    for (final follow in [...?_follows[folder]]) {
      follow.add(hint);
    }
  }

  /// Ends the follows of [folder], as watching does when it is gone.
  void end(RelPath? folder) {
    for (final follow in [...?_follows.remove(folder)]) {
      unawaited(follow.close());
    }
  }
}
