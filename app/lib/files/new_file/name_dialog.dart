import 'package:flutter/material.dart';

/// Asks for a name, under [title]; the name, trimmed, or `null` if the
/// user backed out. Only a name that isn't empty is taken.
Future<String?> showNameDialog(BuildContext context, {required String title}) =>
    showDialog<String>(context: context, builder: (_) => _NameDialog(title));

class _NameDialog extends StatefulWidget {
  const _NameDialog(this.title);

  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _name,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Name'),
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _done(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ListenableBuilder(
        listenable: _name,
        builder: (_, _) => FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _done,
          child: const Text('Create'),
        ),
      ),
    ],
  );
}
