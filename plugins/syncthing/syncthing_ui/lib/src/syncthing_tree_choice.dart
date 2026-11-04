import 'dart:async';

import 'package:truce_core/truce_core.dart';

/// The user's pick of folders to add in one Syncthing folder, in a tree of
/// its folder names. A folder is its path in the Syncthing folder; `null`
/// is the Syncthing folder itself. Folders added before are ticked and
/// locked, as are the folders inside or around them; picking a folder
/// inside or around a picked one swaps it in for that one. So no two
/// folders ever share a file. [changes] tells of each change.
final class SyncthingTreeChoice {
  /// [_names]: the folders to pick from; [taken]: the folders added
  /// before; [initial]: the folder the user picked to start with, picked
  /// if it can be.
  SyncthingTreeChoice({
    required this._names,
    required Set<RelPath?> taken,
    required RelPath? initial,
  }) : _taken = {...taken},
       _picked = {if (!_nestsAny(initial, taken)) initial};

  final SubfolderNames _names;
  final Set<RelPath?> _taken;
  Set<RelPath?> _picked;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires each time the pick changes.
  Stream<void> get changes => _changes.stream;

  /// The folders picked to add, sorted, the Syncthing folder itself first.
  List<RelPath?> get picked => [
    if (_picked.contains(null)) null,
    ...<RelPath>[for (final folder in _picked) ?folder]
      ..sort((a, b) => a.value.compareTo(b.value)),
  ];

  /// Whether [folder] shows a tick: picked, or added before.
  bool isTicked(RelPath? folder) =>
      _picked.contains(folder) || _taken.contains(folder);

  /// Whether [folder] was added before.
  bool isTaken(RelPath? folder) => _taken.contains(folder);

  /// Whether [folder] can't be picked or unpicked: at, inside or around
  /// a folder added before.
  bool isLocked(RelPath? folder) => _nestsAny(folder, _taken);

  /// Whether a ticked folder lies below [folder], so it opens to show it.
  bool holdsTicked(RelPath? folder) => {
    ..._taken,
    ..._picked,
  }.any((ticked) => ticked != null && _below(ticked, folder));

  /// Picks [folder] in place of the picked folders inside or around it,
  /// or unpicks it if it is picked; nothing if it is locked.
  void toggle(RelPath? folder) {
    if (isLocked(folder)) return;
    _picked = _picked.contains(folder)
        ? _picked.difference({folder})
        : {
            for (final picked in _picked)
              if (!_nest(picked, folder)) picked,
            folder,
          };
    _changes.add(null);
  }

  /// The folders in [parent] (the top level if `null`) to pick from,
  /// sorted.
  Future<Result<List<RelPath>, StoreError>> foldersIn(RelPath? parent) async =>
      (await _names.namesIn(parent))
          .map((names) => [for (final name in names) ?_pathOf(parent, name)]);

  /// The pick is no longer shown.
  void dispose() => unawaited(_changes.close());

  static RelPath? _pathOf(RelPath? parent, String name) =>
      parent == null ? RelPath.parse(name) : parent.child(name);

  /// Whether [folder] lies strictly below [above] (`null`: the top).
  static bool _below(RelPath folder, RelPath? above) =>
      above == null || folder.isInside(above);

  /// Whether [folder] lies at, inside or around one of [others].
  static bool _nestsAny(RelPath? folder, Set<RelPath?> others) =>
      others.any((other) => _nest(folder, other));

  static bool _nest(RelPath? a, RelPath? b) =>
      a == b || (a == null || b == null) || a.isInside(b) || b.isInside(a);
}
