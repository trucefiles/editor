import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_activity.dart';
import '../scan/folder_scans_controller.dart';
import 'note_settings_controller.dart';

/// Forgets the settings of notes that are gone, e.g. deleted or renamed
/// outside the app, a while after they went (see `KeptNoteSettings`),
/// each time the app comes into use, so the settings file never keeps
/// growing. Prunes by a scan that started after that.
final noteSettingsPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  // A scan that starts now: an older one may miss notes written since,
  // e.g. one just moved, and their settings would look like a gone note's.
  await ref.read(folderScansProvider.notifier).refresh();
  final scans = ref.read(folderScansProvider).value;
  if (scans == null) return;
  await ref
      .read(noteSettingsProvider.notifier)
      .prune(scans, now: DateTime.now());
});
