import 'package:flutter/material.dart';

import '../../folders/note_folder.dart';
import '../../folders/ui/folder_badge.dart';

/// What the user entered for a new note.
typedef NewNoteInput = ({String title, NoteFolder folder});

/// Asks for a title and the target folder, preselecting [initial].
Future<NewNoteInput?> showNewNoteDialog(
  BuildContext context, {
  required List<NoteFolder> folders,
  required NoteFolder initial,
}) => showDialog<NewNoteInput>(
  context: context,
  builder: (_) => _NewNoteDialog(folders, initial),
);

class _NewNoteDialog extends StatefulWidget {
  const _NewNoteDialog(this.folders, this.initial);

  final List<NoteFolder> folders;
  final NoteFolder initial;

  @override
  State<_NewNoteDialog> createState() => _NewNoteDialogState();
}

class _NewNoteDialogState extends State<_NewNoteDialog> {
  final _title = TextEditingController();
  late NoteFolder _folder = widget.initial;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, (title: title, folder: _folder));
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
            onChanged: (folder) => setState(() => _folder = folder ?? _folder),
          ),
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
