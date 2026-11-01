import 'package:flutter/material.dart';

/// Asks whether to keep the version the user picked, or both merged
/// ([title]); [message] tells what happens to the versions. `true` if
/// confirmed.
Future<bool> confirmKeepVersion(
  BuildContext context,
  String message, {
  String title = 'Keep this version?',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
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
