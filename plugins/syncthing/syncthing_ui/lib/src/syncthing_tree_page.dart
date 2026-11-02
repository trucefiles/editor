import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import 'folder_tree.dart';
import 'syncthing_tree_choice.dart';

/// The page to tick the folders to add in one Syncthing folder. Pops with
/// the folders ticked; with nothing if the user goes back.
class SyncthingTreePage extends StatefulWidget {
  const SyncthingTreePage({
    required this.names,
    required this.rootName,
    required this.taken,
    required this.initial,
    super.key,
  });

  /// The folders in the Syncthing folder to pick from.
  final SubfolderNames names;

  /// The Syncthing folder's name.
  final String rootName;

  /// The folders in it added before (`null`: the Syncthing folder itself).
  final Set<RelPath?> taken;

  /// The folder the user picked, ticked to start with if it can be.
  final RelPath? initial;

  @override
  State<SyncthingTreePage> createState() => _SyncthingTreePageState();
}

class _SyncthingTreePageState extends State<SyncthingTreePage> {
  late final _choice = SyncthingTreeChoice(
    names: widget.names,
    taken: widget.taken,
    initial: widget.initial,
  );

  @override
  void dispose() {
    _choice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Folders to add')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Each ticked folder becomes a folder in the app. Folders '
                  'inside a ticked one show in it.',
                ),
                const SizedBox(height: 8),
                FolderTree(_choice, rootName: widget.rootName),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: StreamBuilder<void>(
                stream: _choice.changes,
                builder: (context, _) => FilledButton(
                  onPressed: _choice.picked.isEmpty
                      ? null
                      : () => Navigator.pop(context, _choice.picked),
                  child: const Text('Next'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
