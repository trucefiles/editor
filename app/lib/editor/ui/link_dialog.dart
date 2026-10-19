import 'package:flutter/material.dart';

/// Asks for a link's address; `null` if the user cancels or enters none.
Future<String?> askLinkUrl(BuildContext context) async {
  final url = await showDialog<String>(
    context: context,
    builder: (context) => const _LinkDialog(),
  );
  final trimmed = url?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _url = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add link'),
    content: TextField(
      controller: _url,
      autofocus: true,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(hintText: 'https://'),
      onSubmitted: (url) => Navigator.pop(context, url),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, _url.text),
        child: const Text('Add'),
      ),
    ],
  );
}
