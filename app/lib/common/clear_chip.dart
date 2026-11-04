import 'package:flutter/material.dart';

/// The chip at the start of a filter row that unpicks every chip in it;
/// a row shows it only while something in it is picked.
class ClearChip extends StatelessWidget {
  const ClearChip({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.close),
    label: const Text('Clear'),
    onPressed: onPressed,
  );
}
