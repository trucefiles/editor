import 'dart:async';

import 'package:truce_core/truce_core.dart';

/// [LiveChanges] driven by the test: [hint] and [end] act on the follows
/// open right now.
final class FakeLiveChanges implements LiveChanges {
  final _follows = <StreamController<ChangeHint>>[];

  /// How many follows were started.
  int followed = 0;

  /// Whether follows end at once, as if the folder were gone.
  bool missing = false;

  @override
  Stream<ChangeHint> follow() {
    followed++;
    final follow = StreamController<ChangeHint>();
    if (missing) {
      unawaited(follow.close());
    } else {
      _follows.add(follow);
      follow.onCancel = () => _follows.remove(follow);
    }
    return follow.stream;
  }

  /// Whether the folder is followed now.
  bool get follows => _follows.isNotEmpty;

  void hint(ChangeHint hint) {
    for (final follow in [..._follows]) {
      follow.add(hint);
    }
  }

  /// Ends the follows, as watching does when the folder is gone.
  void end() {
    for (final follow in [..._follows]) {
      _follows.remove(follow);
      unawaited(follow.close());
    }
  }
}
