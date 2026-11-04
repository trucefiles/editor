import 'package:flutter/material.dart';

import '../../common/confirm_dialog.dart';

/// Asks whether to keep the version the user picked, or both merged
/// ([title]); [message] tells what happens to the versions. `true` if
/// confirmed.
Future<bool> confirmKeepVersion(
  BuildContext context,
  String message, {
  String title = 'Keep this version?',
}) => showConfirmDialog(context, title: title, message: message, yes: 'Keep');
