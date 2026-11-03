import 'package:flutter/material.dart';
import 'package:truce_folders/truce_folders.dart';

/// [folders] in a list the user reorders by dragging. A dropped folder
/// stays where it was dropped while [onMove] saves the move, until the
/// next list of [folders] comes; if saving fails, it goes back.
class ReorderableFolderList extends StatefulWidget {
  const ReorderableFolderList(
    this.folders, {
    required this.onMove,
    required this.tile,
    super.key,
  });

  final List<Folder> folders;
  final Future<bool> Function(Folder folder, int to) onMove;
  final Widget Function(Folder folder, int index) tile;

  @override
  State<ReorderableFolderList> createState() => _ReorderableFolderListState();
}

class _ReorderableFolderListState extends State<ReorderableFolderList> {
  /// The order as dropped, until the saved one comes.
  List<Folder>? _dropped;

  @override
  void didUpdateWidget(ReorderableFolderList old) {
    super.didUpdateWidget(old);
    if (!identical(old.folders, widget.folders)) _dropped = null;
  }

  Future<void> _drop(List<Folder> shown, int from, int to) async {
    final moved = shown[from];
    setState(
      () => _dropped = [...shown]
        ..removeAt(from)
        ..insert(to, moved),
    );
    if (!await widget.onMove(moved, to) && mounted) {
      setState(() => _dropped = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _dropped ?? widget.folders;
    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) => _drop(shown, from, to),
      children: [
        for (final (index, folder) in shown.indexed) widget.tile(folder, index),
      ],
    );
  }
}
