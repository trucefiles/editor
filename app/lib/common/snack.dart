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
          duration: hintDuration(message),
          showCloseIcon: true,
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

/// How long a hint of [message] shows: long enough for a slow reader,
/// growing with its length within Material's 4 to 10 seconds.
Duration hintDuration(String message) => Duration(
  milliseconds: (2000 + message.length * 1000 ~/ 15).clamp(4000, 10000),
);

extension NoticeBanner on ScaffoldMessengerState {
  /// Shows [message] at the top until the user dismisses it, for news
  /// worth reading in full (e.g. how a merge went); short hints at the
  /// bottom never hide it.
  void showNotice(String message) {
    this
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: hideCurrentMaterialBanner,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
  }
}
