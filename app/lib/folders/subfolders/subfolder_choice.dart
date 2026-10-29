import 'dart:async';

import 'package:truce_core/truce_core.dart';

/// The user's choice of what a folder shows of its base folder: the whole
/// of it, or some subfolders, picked in a tree of folder names. Parts
/// another folder of the base folder shows can't be picked: each document
/// is in one folder only. [changes] tells of each change of the choice.
final class SubfolderChoice {
  /// Starts at [initial]; nothing picked if `null`. [taken] are what the
  /// base folder's other folders show; [_names] are the folders the sync
  /// tool offers to pick.
  SubfolderChoice({
    required this._names,
    required this._taken,
    Selection? initial,
  }) : _whole = initial is WholeFolder,
       _picked = switch (initial) {
         Subfolders(:final roots) => {...roots},
         WholeFolder() || null => {},
       };

  final SubfolderNames _names;
  final List<Selection> _taken;
  bool _whole;
  Set<RelPath> _picked;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires each time the choice changes.
  Stream<void> get changes => _changes.stream;

  /// Whether the whole base folder is chosen.
  bool get whole => _whole;

  /// The subfolders picked, while not [whole].
  Set<RelPath> get picked => Set.unmodifiable(_picked);

  /// The choice; `null` while nothing is picked.
  Selection? get selection => switch ((_whole, _picked)) {
    (true, _) => const WholeFolder(),
    (false, final picked) when picked.isEmpty => null,
    (false, final picked) => Selection.of(picked),
  };

  /// Whether another folder shows part of the base folder, so the whole
  /// can't be chosen.
  bool get wholeTaken => _taken.any(const WholeFolder().overlaps);

  void chooseWhole({required bool whole}) {
    _whole = whole;
    _changes.add(null);
  }

  /// Picks [folder], or unpicks it if it is picked.
  void toggle(RelPath folder) {
    _picked = _picked.contains(folder)
        ? ({..._picked}..remove(folder))
        : {..._picked, folder};
    _changes.add(null);
  }

  /// Whether [folder] can't be picked: another folder shows part of it.
  bool isTaken(RelPath folder) => _taken.any(Selection.of([folder]).overlaps);

  /// Whether a folder above [folder] is picked, so it is shown with it.
  bool isInPicked(RelPath folder) =>
      _picked.any((picked) => folder.isInside(picked));

  /// Whether a folder below [folder] is picked, so it opens to show it.
  bool holdsPicked(RelPath folder) =>
      _picked.any((picked) => picked.isInside(folder));

  /// The folders in [parent] (the base folder's top level if `null`) the
  /// user can pick from, sorted.
  Future<Result<List<RelPath>, StoreError>> foldersIn(RelPath? parent) async =>
      switch (await _names.namesIn(parent)) {
        Ok(value: final names) => Ok([
          for (final name in names) ?_pathOf(parent, name),
        ]),
        Err(:final error) => Err(error),
      };

  /// The choice is no longer shown.
  void dispose() => unawaited(_changes.close());

  static RelPath? _pathOf(RelPath? parent, String name) =>
      parent == null ? RelPath.parse(name) : parent.child(name);
}
