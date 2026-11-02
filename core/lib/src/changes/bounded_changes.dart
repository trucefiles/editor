import 'dart:async';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/folders_there.dart';
import '../storage/rel_path.dart';
import 'folder_changes.dart';
import 'live_changes.dart';

/// The changes of what the app may see in one folder: its live follow,
/// with hints only for paths [counts] lets through. Built by
/// `BoundedPlace`.
///
/// Heals on its own: when the follow ends (the folder is gone, or watching
/// failed), it asks for a listing, then checks every [checkEvery] whether
/// the folder is there; once it is, it asks for a listing again and
/// follows it live again. Never ends on its own.
final class BoundedChanges implements FolderChanges {
  const BoundedChanges(
    this._live,
    this._files, {
    required this.counts,
    required this.checkEvery,
  });

  final LiveChanges _live;

  /// The folder's files, to check whether it is back.
  final FileStore _files;

  /// Whether a change of the file at a path is passed on.
  final bool Function(RelPath file) counts;

  /// How long to wait before each check; read as each wait starts.
  final Duration Function() checkEvery;

  @override
  Stream<ChangeHint> get changes => _Run(this).out.stream;

  bool _passes(ChangeHint hint) => switch (hint) {
    PathChanged(:final path) => counts(path),
    ListAgain() => true,
  };

  /// Whether the folder is there now, by one listing of its top level.
  Future<bool> _there() async => await _files.foldersThere(const {}) is Ok;
}

/// One listen of [BoundedChanges]: its live follow, or the wait before
/// the next check while it ended.
final class _Run {
  _Run(this._changes) {
    out = StreamController<ChangeHint>(onListen: _follow, onCancel: _stop);
  }

  final BoundedChanges _changes;
  late final StreamController<ChangeHint> out;
  StreamSubscription<ChangeHint>? _following;
  Timer? _wait;
  var _stopped = false;

  void _follow() {
    _following = _changes._live
        .follow()
        .where(_changes._passes)
        .listen(out.add, onDone: _onEnd);
  }

  /// Changes may have been missed: lists again, then waits to check.
  void _onEnd() {
    if (_stopped) return;
    _following = null;
    out.add(const ListAgain());
    _wait = Timer(_changes.checkEvery(), _check);
  }

  Future<void> _check() async {
    final back = await _changes._there();
    _wait = null;
    if (_stopped) return;
    if (back) {
      _follow();
      out.add(const ListAgain());
    } else {
      _wait = Timer(_changes.checkEvery(), _check);
    }
  }

  Future<void> _stop() async {
    _stopped = true;
    _wait?.cancel();
    await _following?.cancel();
  }
}
