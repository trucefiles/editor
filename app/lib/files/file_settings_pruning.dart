import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folder_state/folder_state_controller.dart';
import '../platform/app_activity.dart';
import 'file_settings_controller.dart';

/// Forgets the settings of files that are gone, e.g. deleted or renamed
/// outside the app, a while after they went (see `KeptFileSettings`),
/// each time the app comes into use, so the settings file never keeps
/// growing. Prunes by a listing that started after that.
final fileSettingsPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  // A listing that starts now: an older one may miss files written
  // since, e.g. one just moved, and their settings would look like a gone
  // file's.
  final contents = await ref.read(folderContentsProvider.notifier).refresh();
  if (contents == null) return;
  await ref
      .read(fileSettingsProvider.notifier)
      .prune(contents.shown, now: DateTime.now());
});
