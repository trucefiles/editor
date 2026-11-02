import 'package:flutter/widgets.dart';
import 'package:truce_core/truce_core.dart';

import '../common/snack.dart';
import '../platform/folder_picker.dart';

/// Asks the user for a folder on this device with [picker], for a
/// plugin's add page; `null` if cancelled, or if it can't be opened (then
/// the user is told).
Future<Uri?> pickFolder(BuildContext context, FolderPicker picker) async {
  final picked = await picker.pick();
  switch (picked) {
    case Ok(:final value):
      return value;
    case Err(error: PickError.unsupportedLocation):
      if (context.mounted) {
        showSnack(
          context,
          "This folder can't be opened by the app. Folders on the "
          "device's main storage can.",
        );
      }
      return null;
  }
}
