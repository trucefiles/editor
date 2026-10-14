import 'package:flutter/material.dart';

/// A menu label with a checkbox icon that shows on and off alike, so it
/// lines up with plain menu items.
class ToggleLabel extends StatelessWidget {
  const ToggleLabel(this.label, {required this.on, this.hint, super.key});

  final String label;
  final bool on;

  /// A second line, e.g. why the setting has no effect right now.
  final String? hint;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: hint == null
            ? Text(label)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  Text(hint!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
      ),
      Icon(on ? Icons.check_box : Icons.check_box_outline_blank),
    ],
  );
}
