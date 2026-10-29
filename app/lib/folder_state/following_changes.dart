import 'dart:async';

import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';

/// Passes what each base folder's changes hint on to the folder state
/// owner while the app is in use, and tells it whether the app is in use;
/// the owner decides what to list or check. Changes made while the app
/// was not in use are the screens' to catch up on, as they do in every
/// way of refreshing.
final class FollowingChanges {
  FollowingChanges(this._owner);

  final FolderStateOwner _owner;

  /// Whether the app is in use, as last told; `null` before the first
  /// [follow].
  bool? _active;

  /// The changes followed, by base folder id; none while the app is not
  /// in use.
  Map<String, FolderChanges> _followed = const {};
  List<StreamSubscription<ChangeHint>> _subscriptions = const [];

  /// Follows [changes], how each base folder's changes are found by its
  /// id, while [active], the app is in use.
  void follow({
    required bool active,
    required Map<String, FolderChanges> changes,
  }) {
    if (active != _active) _owner.send(Active(active: active));
    _active = active;
    final followed = active ? changes : const <String, FolderChanges>{};
    if (const MapEquality<String, FolderChanges>().equals(
      followed,
      _followed,
    )) {
      return;
    }
    _stop();
    _followed = followed;
    _subscriptions = [
      for (final MapEntry(key: baseId, value: changes) in followed.entries)
        changes.changes.listen((hint) => _owner.send(Hinted(baseId, hint))),
    ];
  }

  /// Lists every base folder once, e.g. as the way changes are found
  /// changed: for changes made while nothing was looking.
  void listAgain() => _owner.send(Refresh(Ticket()));

  /// Stops following.
  void close() => _stop();

  void _stop() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions = const [];
  }
}
