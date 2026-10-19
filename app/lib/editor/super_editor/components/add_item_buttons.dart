import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// Buttons that add an item to a list, one per kind: checkbox, bullet and
/// numbered item.
class AddItemButtons extends StatelessWidget {
  const AddItemButtons({required this.onAdd, super.key});

  final ValueChanged<ListKind> onAdd;

  static const _buttons = [
    (ListKind.checkbox, Icons.check_box_outlined, 'Add checkbox'),
    (ListKind.bullet, Icons.format_list_bulleted, 'Add bullet'),
    (ListKind.numbered, Icons.format_list_numbered, 'Add numbered item'),
  ];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (kind, icon, label) in _buttons)
        IconButton(
          tooltip: label,
          icon: Icon(icon),
          onPressed: () => onAdd(kind),
        ),
    ],
  );
}
