import 'dart:async';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/folders_there.dart';
import '../storage/rel_path.dart';
import '../storage/selection.dart';
import 'folder_changes.dart';
import 'live_changes.dart';

/// The changes of what the app may see in one base folder: one live follow
/// per selected subfolder (the whole base folder if all is selected), with
/// hints only for paths [counts] lets through. Built by `BoundedPlace`.
///
/// Heals on its own: when the follow of one subfolder ends (it is gone,
/// or watching failed), it asks for a listing, then checks every
/// [checkEvery] whether that subfolder is there; once it is, it asks for
/// a listing again and follows it live again. A follow that keeps ending
/// right after it starts again (watching fails while the folder is
/// there) asks for one listing per wait, at its end. The other
/// subfolders keep their live follow meanwhile. One check covers all ended follows, so a
/// gone base folder costs one listing per wait. Never ends on its own.
final class BoundedChanges implements FolderChanges {
  const BoundedChanges(
    this._live,
    this._files,
    this._selection, {
    required this.counts,
    required this.checkEvery,
  });

  final LiveChanges _live;

  /// The base folder's files, to check whether a subfolder is back.
  final FileStore _files;

  final Selection _selection;

  /// Whether a change of the file at a path is passed on.
  final bool Function(RelPath file) counts;

  /// How long to wait before each check; read as each wait starts.
  final Duration Function() checkEvery;

  @override
  Stream<ChangeHint> get changes => _Run(this).out.stream;

  /// The folders followed: the base folder itself (`null`) when all is
  /// selected, else each selected subfolder.
  Iterable<RelPath?> get _roots => switch (_selection) {
    WholeFolder() => const [null],
    Subfolders(:final roots) => roots,
  };

  bool _passes(ChangeHint hint) => switch (hint) {
    PathChanged(:final path) => _selection.covers(path) && counts(path),
    ListAgain() => true,
  };

  /// Which of [roots] are there now, by one listing; none if the base
  /// folder can't be listed.
  Future<Set<RelPath?>> _there(Set<RelPath?> roots) async =>
      switch (await _files.foldersThere({for (final root in roots) ?root})) {
        Ok(value: final there) => {if (roots.contains(null)) null, ...there},
        Err() => const {},
      };
}

/// One listen of [BoundedChanges]: its live follows, the ones that ended,
/// and the wait before the next check.
final class _Run {
  _Run(this._changes) {
    out = StreamController<ChangeHint>(
      onListen: () => _changes._roots.forEach(_follow),
      onCancel: _stop,
    );
  }

  final BoundedChanges _changes;
  late final StreamController<ChangeHint> out;
  final _follows = <RelPath?, StreamSubscription<ChangeHint>>{};
  final _ended = <RelPath?>{};

  /// How long ago each follow started again by a check.
  final _sinceFollowedAgain = <RelPath?, Stopwatch>{};

  /// The ended ones whose follow ended within a wait of starting again.
  final _failing = <RelPath?>{};
  Timer? _wait;
  var _stopped = false;

  void _follow(RelPath? root) {
    _follows[root] = _changes._live
        .below(root)
        .where(_changes._passes)
        .listen(out.add, onDone: () => _onEnd(root));
  }

  /// Changes may have been missed: lists again, then waits to check.
  void _onEnd(RelPath? root) {
    if (_stopped) return;
    _follows.remove(root);
    _ended.add(root);
    final since = _sinceFollowedAgain.remove(root)?.elapsed;
    if (since != null && since < _changes.checkEvery()) {
      _failing.add(root);
    } else {
      _failing.remove(root);
    }
    out.add(const ListAgain());
    _wait ??= Timer(_changes.checkEvery(), _check);
  }

  Future<void> _check() async {
    final back = await _changes._there({..._ended});
    _wait = null;
    if (_stopped) return;
    final cameBack = back.difference(_failing);
    _ended.removeAll(back);
    for (final root in back) {
      _sinceFollowedAgain[root] = Stopwatch()..start();
      _follow(root);
    }
    if (cameBack.isNotEmpty) out.add(const ListAgain());
    if (_ended.isNotEmpty) _wait = Timer(_changes.checkEvery(), _check);
  }

  Future<void> _stop() async {
    _stopped = true;
    _wait?.cancel();
    await Future.wait(_follows.values.map((follow) => follow.cancel()));
  }
}
