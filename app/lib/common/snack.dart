import 'package:flutter/material.dart';

/// Shows [message] at the bottom for a few seconds, with an optional
/// action such as undo.
void showSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) =>
    ScaffoldMessenger.of(context)
        .showHint(message, actionLabel: actionLabel, onAction: onAction);

extension HintSnackBar on ScaffoldMessengerState {
  /// Like [showSnack]; for when the screen that asked may be gone by then,
  /// e.g. after an undo.
  void showHint(String message, {String? actionLabel, VoidCallback? onAction}) {
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Flutter keeps snack bars with an action open until dismissed;
          // these are short hints, so they go away on their own.
          persist: false,
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }
}
