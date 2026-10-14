import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../folders/note_folder.dart';
import '../../folders/ui/folder_badge.dart';

/// What the user entered for a new note. [subfolder] is `null` for the
/// folder's top level.
typedef NewNoteInput = ({String title, NoteFolder folder, RelPath? subfolder});

/// Asks for a title, the target folder (preselecting [initial]) and, if
/// [subfoldersOf] the folder offers any, one of its subfolders.
Future<NewNoteInput?> showNewNoteDialog(
  BuildContext context, {
  required List<NoteFolder> folders,
  required NoteFolder initial,
  required List<RelPath> Function(NoteFolder folder) subfoldersOf,
}) => showDialog<NewNoteInput>(
  context: context,
  builder: (_) => _NewNoteDialog(folders, initial, subfoldersOf),
);

class _NewNoteDialog extends StatefulWidget {
  const _NewNoteDialog(this.folders, this.initial, this.subfoldersOf);

  final List<NoteFolder> folders;
  final NoteFolder initial;
  final List<RelPath> Function(NoteFolder folder) subfoldersOf;

  @override
  State<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<_NewNoteDialog> {
  final _title = TextEditingController();
  late NoteFolder _folder = widget.initial;
  RelPath? _subfolder;

  List<RelPath> get _subfolders => widget.subfoldersOf(_folder);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, (
      title: title,
      folder: _folder,
      subfolder: _subfolder,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
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
              initialValue: null,
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
