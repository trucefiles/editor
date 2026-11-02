import 'dart:async';

import 'package:truce_core/truce_core.dart';
import 'package:truce_folders/truce_folders.dart';

/// Where adding folders stands.
sealed class AddFolderStep {
  const AddFolderStep();
}

/// The user picks the plugin to add folders with.
final class ChoosingPlugin extends AddFolderStep {
  const ChoosingPlugin();
}

/// The user names and colors the new folder at [location], number
/// [index] of [count].
final class NamingFolder extends AddFolderStep {
  const NamingFolder({
    required this.index,
    required this.count,
    required this.location,
    required this.name,
    required this.color,
  });

  final int index;
  final int count;
  final String location;
  final String name;
  final String color;

  /// Whether this is the last folder to name.
  bool get isLast => index == count - 1;

  /// Whether [name] is one a folder can have ([Folder.nameFrom]); the
  /// flow goes on only then.
  bool get hasName => Folder.nameFrom(name) != null;
}

/// Adding folders, step by step: the plugin, its add page's candidates,
/// then a name and a color for each new folder in turn; then all are
/// added together, or none. Cancelling anywhere adds nothing. [changes]
/// tells of each change of [step].
final class AddFolderFlow {
  /// New folders get colors from [_colors], the palette's names in order,
  /// unlike [usedColors] and each other where it can; added with [_add].
  AddFolderFlow({
    required this._colors,
    required Iterable<String> usedColors,
    required this._add,
  }) : _usedColors = [...usedColors];

  final List<String> _colors;
  final List<String> _usedColors;
  final Future<Result<List<Folder>, FolderError>> Function(
    FolderPlugin plugin,
    List<NamedCandidate> candidates,
  )
  _add;

  FolderPlugin? _plugin;
  List<NamedCandidate> _named = const [];
  int _index = 0;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires each time [step] changes.
  Stream<void> get changes => _changes.stream;

  AddFolderStep get step => switch (_plugin) {
    null => const ChoosingPlugin(),
    _ => NamingFolder(
      index: _index,
      count: _named.length,
      location: _named[_index].candidate.location,
      name: _named[_index].name,
      color: _named[_index].color,
    ),
  };

  /// [plugin]'s add page gave [candidates]: on to name the first; nothing
  /// changes if it gave none.
  void took(FolderPlugin plugin, List<PluginFolderCandidate> candidates) {
    if (candidates.isEmpty) return;
    _plugin = plugin;
    _index = 0;
    _named = candidates.fold(
      const <NamedCandidate>[],
      (named, candidate) => [
        ...named,
        (
          candidate: candidate,
          name: candidate.defaultName,
          color: nextFolderColor([
            ..._usedColors,
            for (final before in named) before.color,
          ], _colors),
        ),
      ],
    );
    _changes.add(null);
  }

  void rename(String name) => _changeShown(
    (named) => (candidate: named.candidate, name: name, color: named.color),
  );

  void recolor(String color) => _changeShown(
    (named) => (candidate: named.candidate, name: named.name, color: color),
  );

  /// On to the next folder to name, once this one has a name.
  void next() {
    if (step case NamingFolder(isLast: false, hasName: true)) {
      _index++;
      _changes.add(null);
    }
  }

  /// Back one step: to the folder named before, or from the first to the
  /// plugins, which drops the candidates. `false` at the plugins: then
  /// the flow ends.
  bool back() {
    switch (step) {
      case ChoosingPlugin():
        return false;
      case NamingFolder(index: 0):
        _plugin = null;
        _named = const [];
      case NamingFolder():
        _index--;
    }
    _changes.add(null);
    return true;
  }

  /// Adds every named folder, all together or none, each by its name as
  /// [Folder.nameFrom] has it; the folders added. Only once every folder
  /// has a name ([NamingFolder.hasName]).
  Future<Result<List<Folder>, FolderError>> finish() => switch (_plugin) {
    final plugin? => _add(plugin, [
      for (final named in _named)
        (
          candidate: named.candidate,
          name:
              Folder.nameFrom(named.name) ??
              (throw StateError('A folder to add has no name')),
          color: named.color,
        ),
    ]),
    null => throw StateError('Nothing to add before a plugin gave folders'),
  };

  void dispose() => unawaited(_changes.close());

  void _changeShown(NamedCandidate Function(NamedCandidate named) change) {
    if (_plugin == null) return;
    _named = [
      for (final (index, named) in _named.indexed)
        index == _index ? change(named) : named,
    ];
    _changes.add(null);
  }
}
