import 'package:flutter/material.dart';

/// Asks whether to keep the version the user picked; [message] tells what
/// happens to the other one. `true` if confirmed.
Future<bool> confirmKeepVersion(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keep this version?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Keep'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
