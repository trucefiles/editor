import 'package:flutter/material.dart';

/// Asks whether the user drops an open file's content that can be kept
/// nowhere: [title] and [message] say what, [discard] names dropping it.
/// Whether they drop it.
Future<bool> askToDiscard(
  BuildContext context, {
  required String title,
  required String message,
  required String discard,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
        ],
      ),
    ) ??
    false;
