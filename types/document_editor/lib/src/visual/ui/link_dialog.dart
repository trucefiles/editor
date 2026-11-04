import 'package:flutter/material.dart';

/// What the user chose in the link dialog.
sealed class LinkAnswer {
  const LinkAnswer();
}

/// Show [text] as a link to [url]; an empty [text] shows the [url].
final class LinkSet extends LinkAnswer {
  const LinkSet(this.text, this.url);

  final String text;
  final String url;
}

/// Take the link away, its text kept.
final class LinkRemoved extends LinkAnswer {
  const LinkRemoved();
}

/// Open the link.
final class LinkOpened extends LinkAnswer {
  const LinkOpened();
}

/// Asks for a link's text and address: to add one showing [text] when
/// [url] is `null`, else to edit the link there, which can also be opened
/// and, if [removable], removed. `null` if the user cancels or leaves the
/// address empty.
Future<LinkAnswer?> askLink(
  BuildContext context, {
  required String text,
  String? url,
  bool removable = false,
}) => showDialog<LinkAnswer>(
  context: context,
  builder: (context) => _LinkDialog(text: text, url: url, removable: removable),
);

/// [address] as a link leads: one typed without a scheme (e.g.
/// `www.example.com`) gets `https://`; one that leads within the folder
/// or the document (`/`, `./`, `../`, `#`) stays as typed.
String withScheme(String address) {
  final trimmed = address.trim();
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
  final local = ['/', './', '../', '#'].any(trimmed.startsWith);
  return hasScheme || local || trimmed.isEmpty ? trimmed : 'https://$trimmed';
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({
    required this.text,
    required this.url,
    required this.removable,
  });

  final String text;
  final String? url;
  final bool removable;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _text = TextEditingController(text: widget.text);
  late final _url = TextEditingController(text: widget.url);

  bool get _editing => widget.url != null;

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final url = withScheme(_url.text);
    Navigator.pop(context, url.isEmpty ? null : LinkSet(_text.text, url));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_editing ? 'Edit link' : 'Add link'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _text,
          decoration: const InputDecoration(labelText: 'Text'),
          textInputAction: TextInputAction.next,
        ),
        TextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Address',
            hintText: 'https://',
          ),
          onSubmitted: (_) => _save(),
        ),
      ],
    ),
    actions: [
      if (_editing && widget.removable)
        TextButton(
          onPressed: () => Navigator.pop(context, const LinkRemoved()),
          child: const Text('Remove link'),
        ),
      if (_editing)
        TextButton(
          onPressed: () => Navigator.pop(context, const LinkOpened()),
          child: const Text('Open'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: Text(_editing ? 'Save' : 'Add')),
    ],
  );
}
