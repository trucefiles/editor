import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/note_folder.dart';
import '../../folders/ui/folder_badge.dart';
import '../note_place.dart';

/// Asks for a folder of [folders] and, if [subfoldersOf] the folder offers
/// any, one of its subfolders, starting at [initial]; titled [title], with
/// [action] on the confirming button. The chosen place, or `null` if
/// cancelled.
Future<NotePlace?> showNotePlaceDialog(
  BuildContext context, {
  required String title,
  required String action,
  required List<NoteFolder> folders,
  required NotePlace initial,
  required List<RelPath> Function(NoteFolder folder) subfoldersOf,
}) async => (await showDialog<_Choice>(
  context: context,
  builder: (_) =>
      _NotePlaceDialog(title, action, folders, initial, subfoldersOf, null),
))?.place;

/// Like [showNotePlaceDialog], also asking for a note's file name without
/// its extension, starting at [name]. The chosen place and name as typed,
/// or `null` if cancelled.
Future<({NotePlace place, String name})?> showNoteFileDialog(
  BuildContext context, {
  required List<NoteFolder> folders,
  required NotePlace initial,
  required String name,
  required List<RelPath> Function(NoteFolder folder) subfoldersOf,
}) async => switch (await showDialog<_Choice>(
  context: context,
  builder: (_) => _NotePlaceDialog(
    'Place and name',
    'OK',
    folders,
    initial,
    subfoldersOf,
    name,
  ),
)) {
  (:final place, name: final name?) => (place: place, name: name),
  _ => null,
};

typedef _Choice = ({NotePlace place, String? name});

class _NotePlaceDialog extends StatefulWidget {
  const _NotePlaceDialog(
    this.title,
    this.action,
    this.folders,
    this.initial,
    this.subfoldersOf,
    this.name,
  );

  final String title;
  final String action;
  final List<NoteFolder> folders;
  final NotePlace initial;
  final List<RelPath> Function(NoteFolder folder) subfoldersOf;

  /// The file name to start at; `null` asks for none.
  final String? name;

  @override
  State<_NotePlaceDialog> createState() => _NotePlaceDialogState();
}

class _NotePlaceDialogState extends State<_NotePlaceDialog> {
  late NoteFolder _folder = widget.folders.contains(widget.initial.folder)
      ? widget.initial.folder
      : widget.folders.first;
  late RelPath? _subfolder = _subfolders.contains(widget.initial.subfolder)
      ? widget.initial.subfolder
      : null;

  late final _name = TextEditingController(text: widget.name);

  List<RelPath> get _subfolders => widget.subfoldersOf(_folder);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.pop<_Choice>(context, (
    place: (folder: _folder, subfolder: _subfolder),
    name: widget.name == null ? null : _name.text,
  ));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<NoteFolder>(
            initialValue: _folder,
            decoration: const InputDecoration(labelText: 'Folder'),
            items: [
              for (final folder in widget.folders)
                DropdownMenuItem(value: folder, child: FolderBadge(folder)),
            ],
            onChanged: (folder) => setState(() {
              _folder = folder ?? _folder;
              _subfolder = null;
            }),
          ),
          if (_subfolders case final subfolders when subfolders.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<RelPath?>(
              // A new key per folder resets the field to the top level.
              key: ValueKey(_folder.id),
              initialValue: _subfolder,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Subfolder'),
              items: [
                const DropdownMenuItem(child: Text('Top level')),
                for (final subfolder in subfolders)
                  DropdownMenuItem(
                    value: subfolder,
                    child: Text(
                      subfolder.value,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (subfolder) => setState(() => _subfolder = subfolder),
            ),
          ],
          if (widget.name != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'From the first line',
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.action)),
      ],
    );
  }
}
