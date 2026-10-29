import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../../common/error_text.dart';
import '../subfolder_choice.dart';

/// The base folder's subfolders as a tree to pick from, one level read
/// at a time as the user opens a folder. Not scrollable itself: it goes
/// inside a scrolling page.
class SubfolderTree extends StatelessWidget {
  const SubfolderTree(this.choice, {super.key});

  final SubfolderChoice choice;

  @override
  Widget build(BuildContext context) => _Level(choice, parent: null);
}

/// The folders in [parent], read when shown.
class _Level extends StatefulWidget {
  const _Level(this.choice, {required this.parent});

  final SubfolderChoice choice;
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
                ? const ListTile(title: Text('This folder has no subfolders.'))
                : const SizedBox.shrink(),
          Ok(value: final folders) => Column(
            children: [
              for (final folder in folders) _Node(widget.choice, folder),
            ],
          ),
          Err(:final error) => ListTile(title: Text(error.text)),
        },
      );
}

/// One folder: ticked to pick it, opened to show its own folders.
class _Node extends StatelessWidget {
  const _Node(this.choice, this.folder);

  final SubfolderChoice choice;
  final RelPath folder;

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: choice.changes,
    builder: (context, _) {
      final inPicked = choice.isInPicked(folder);
      final taken = choice.isTaken(folder);
      return ExpansionTile(
        controlAffinity: ListTileControlAffinity.leading,
        initiallyExpanded: choice.holdsPicked(folder),
        title: Text(folder.name),
        subtitle: taken ? const Text('In another folder') : null,
        trailing: Checkbox(
          value: inPicked || choice.picked.contains(folder),
          onChanged: inPicked || taken ? null : (_) => choice.toggle(folder),
        ),
        childrenPadding: const EdgeInsetsDirectional.only(start: 24),
        children: [_Level(choice, parent: folder)],
      );
    },
  );
}
