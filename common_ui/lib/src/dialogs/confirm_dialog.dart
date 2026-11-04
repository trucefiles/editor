import 'package:flutter/material.dart';

/// Asks the user [title], with [message] on what follows if given; `true`
/// once they pick [yes], `false` on [no] or when they close the dialog.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String yes,
  String no = 'Cancel',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: switch (message) {
          final message? => Text(message),
          null => null,
        },
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(no),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(yes),
          ),
        ],
      ),
    ) ??
    false;
