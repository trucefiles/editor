import 'package:flutter/material.dart';

/// The small popup at a link the caret is in, as in other editors: the
/// link's address [url], and buttons to open it, edit it and, if
/// [onRemove] is given, remove it.
class LinkPopup extends StatelessWidget {
  const LinkPopup(
    this.url, {
    required this.onOpen,
    required this.onEdit,
    this.onRemove,
    super.key,
  });

  final String url;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 3,
    borderRadius: BorderRadius.circular(8),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            tooltip: 'Open link',
            icon: const Icon(Icons.open_in_new),
            onPressed: onOpen,
          ),
          IconButton(
            tooltip: 'Edit link',
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          if (onRemove case final remove?)
            IconButton(
              tooltip: 'Remove link',
              icon: const Icon(Icons.link_off),
              onPressed: remove,
            ),
        ],
      ),
    ),
  );
}
