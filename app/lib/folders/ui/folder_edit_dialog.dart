import 'package:flutter/material.dart';

import '../document_folder.dart';
import '../folder_colors.dart';

/// Edits a folder's name and color; returns the changed folder, or `null`
/// if cancelled.
Future<DocumentFolder?> showFolderEditDialog(
  BuildContext context,
  DocumentFolder folder,
) => showDialog<DocumentFolder>(
  context: context,
  builder: (_) => _FolderEditDialog(folder),
);

class _FolderEditDialog extends StatefulWidget {
  const _FolderEditDialog(this.folder);

  final DocumentFolder folder;

  @override
  State<_FolderEditDialog> createState() => _FolderEditDialogState();
}

class _FolderEditDialogState extends State<_FolderEditDialog> {
  late final _name = TextEditingController(text: widget.folder.name);
  late Color _color = widget.folder.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, widget.folder.copyWith(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Folder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.folder.path,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in folderColors)
                _ColorChoice(
                  color: color,
                  selected: color.toARGB32() == _color.toARGB32(),
                  onTap: () => setState(() => _color = color),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: color,
        child: selected ? const Icon(Icons.check, color: Colors.white) : null,
      ),
    );
  }
}
