import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import 'syncthing_tree_choice.dart';

/// The Syncthing folder [rootName] and its folders as a tree to pick
/// from, one level read at a time as the user opens a folder. Not
/// scrollable itself: it goes inside a scrolling page.
class FolderTree extends StatelessWidget {
  const FolderTree(this.choice, {required this.rootName, super.key});

  final SyncthingTreeChoice choice;
  final String rootName;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Tick(choice, null, title: 'Syncthing folder $rootName'),
      const Divider(),
      _Level(choice, parent: null),
    ],
  );
}

/// The folders in [parent], read when shown.
class _Level extends StatefulWidget {
  const _Level(this.choice, {required this.parent});

  final SyncthingTreeChoice choice;
  final RelPath? parent;

  @override
  State<_Level> createState() => _LevelState();
}

class _LevelState extends State<_Level> {
  late final _folders = widget.choice.foldersIn(widget.parent);

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<Result<List<RelPath>, StoreError>>(
        future: _folders,
        builder: (context, snapshot) => switch (snapshot.data) {
          null => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          ),
          Ok(value: final folders) when folders.isEmpty =>
            widget.parent == null
                ? const ListTile(title: Text('No folders inside.'))
                : const SizedBox.shrink(),
          Ok(value: final folders) => Column(
            children: [
              for (final folder in folders) _Node(widget.choice, folder),
            ],
          ),
          Err() => const ListTile(title: Text("These folders can't be read.")),
        },
      );
}

/// One folder: ticked to pick it, opened to show its own folders.
class _Node extends StatelessWidget {
  const _Node(this.choice, this.folder);

  final SyncthingTreeChoice choice;
  final RelPath folder;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    controlAffinity: ListTileControlAffinity.leading,
    initiallyExpanded: choice.holdsTicked(folder),
    title: Text(folder.name),
    subtitle: choice.isTaken(folder) ? const Text('Added before') : null,
    trailing: _Box(choice, folder),
    childrenPadding: const EdgeInsetsDirectional.only(start: 24),
    children: [_Level(choice, parent: folder)],
  );
}

/// The Syncthing folder itself, ticked to pick it as a whole.
class _Tick extends StatelessWidget {
  const _Tick(this.choice, this.folder, {required this.title});

  final SyncthingTreeChoice choice;
  final RelPath? folder;
  final String title;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: choice.isTaken(folder) ? const Text('Added before') : null,
    trailing: _Box(choice, folder),
  );
}

/// The tick of [folder], locked where it can't change.
class _Box extends StatelessWidget {
  const _Box(this.choice, this.folder);

  final SyncthingTreeChoice choice;
  final RelPath? folder;

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: choice.changes,
    builder: (context, _) => Checkbox(
      value: choice.isTicked(folder),
      onChanged: choice.isLocked(folder) ? null : (_) => choice.toggle(folder),
    ),
  );
}
