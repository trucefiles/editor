import 'package:flutter/material.dart';

import '../../common/snack.dart';

/// Closes the file page of [context] if it is still the top screen (the
/// user may have left it meanwhile).
void closeIfOnTop(BuildContext context) {
  if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
    Navigator.pop(context);
  }
}

/// Closes the file page of [context] and every screen or dialog open on
/// top of it.
void closeWithAllOnTop(BuildContext context) {
  final route = context.mounted ? ModalRoute.of(context) : null;
  if (route == null || !route.isActive) return;
  Navigator.of(context)
    ..popUntil((top) => top == route)
    ..pop();
}

/// Closes the file page of [context] as its folder was removed from the
/// app, and says why.
void closeAsFolderRemoved(BuildContext context) {
  ScaffoldMessenger.of(context)
      .showHint('The file closed because its folder was removed from the app.');
  closeWithAllOnTop(context);
}
