import 'package:flutter/material.dart';

/// Asks the user [title], with [message] on what follows; `true` once
/// they pick [yes], `false` on Cancel or when they close the dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String yes,
}) async =>
    await showDialog<bool>(
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
            child: Text(yes),
          ),
        ],
      ),
    ) ??
    false;
