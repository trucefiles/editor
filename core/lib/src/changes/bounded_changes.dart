import 'dart:async';

import '../common/result.dart';
import '../storage/file_store.dart';
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
/// a listing again and follows it live again. The other subfolders keep
/// their live follow meanwhile. One check covers all ended follows, so a
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

  /// Which of [roots] are there now, by one listing that walks only the
  /// way to them; none if the base folder can't be listed.
  Future<Set<RelPath?>> _there(Set<RelPath?> roots) async {
    final listed = await _files.list(
      enterFolder: (folder) => roots.any(
        (root) =>
            root != null &&
            (root == folder || Selection.isInside(root, folder)),
      ),
      includeFile: (_) => false,
    );
    return switch (listed) {
      Ok(value: final listing) => {
        for (final root in roots)
          if (root == null || listing.folders.contains(root)) root,
      },
      Err() => const {},
    };
  }
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
    out.add(const ListAgain());
    _wait ??= Timer(_changes.checkEvery(), _check);
  }

  Future<void> _check() async {
    final back = await _changes._there({..._ended});
    _wait = null;
    if (_stopped) return;
    _ended.removeAll(back);
    back.forEach(_follow);
    if (back.isNotEmpty) out.add(const ListAgain());
    if (_ended.isNotEmpty) _wait = Timer(_changes.checkEvery(), _check);
  }

  Future<void> _stop() async {
    _stopped = true;
    _wait?.cancel();
    await Future.wait(_follows.values.map((follow) => follow.cancel()));
  }
}
