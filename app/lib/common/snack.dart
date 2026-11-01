import 'package:flutter/material.dart';

/// Shows [message] at the bottom for a few seconds, with an optional
/// action such as undo; [untilDismissed]: it stays until the user closes
/// it, for news worth reading in full (e.g. how a merge went).
void showSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  bool untilDismissed = false,
}) => ScaffoldMessenger.of(context).showHint(
  message,
  actionLabel: actionLabel,
  onAction: onAction,
  untilDismissed: untilDismissed,
);

extension HintSnackBar on ScaffoldMessengerState {
  /// Like [showSnack]; for when the screen that asked may be gone by then,
  /// e.g. after an undo.
  void showHint(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    bool untilDismissed = false,
  }) {
    this
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // Flutter keeps snack bars with an action open until dismissed;
          // short hints go away on their own.
          persist: untilDismissed,
          showCloseIcon: untilDismissed,
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }
}
