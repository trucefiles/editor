import 'package:flutter/material.dart';

/// The chip at the start of a filter row that unpicks every chip in it;
/// a row shows it only while something in it is picked. Filled in the
/// theme's inverse colors and without an outline, so it reads as an
/// action, not as one more filter (a picked filter is filled in a tone).
class ClearChip extends StatelessWidget {
  const ClearChip({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(Icons.close, color: colors.onInverseSurface),
      label: const Text('Clear'),
      labelStyle: TextStyle(color: colors.onInverseSurface),
      backgroundColor: colors.inverseSurface,
      side: BorderSide.none,
      onPressed: onPressed,
    );
  }
}
