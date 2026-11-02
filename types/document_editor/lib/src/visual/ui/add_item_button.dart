import 'package:flutter/material.dart';

/// The button that adds an item to a list, lined up with the list's
/// boxes, which follow its items' drag handles, [indent] wide.
class AddItemButton extends StatelessWidget {
  const AddItemButton({required this.indent, required this.onAdd, super.key});

  final double indent;
  final VoidCallback onAdd;

  /// How far the button's icon is drawn in from its edge.
  static const _iconInset = 8.0;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.only(left: indent - _iconInset),
      child: TextButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
        style: TextButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    ),
  );
}
