import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folder_state/folder_state_controller.dart';
import '../platform/app_activity.dart';
import 'document_settings_controller.dart';

/// Forgets the settings of documents that are gone, e.g. deleted or renamed
/// outside the app, a while after they went (see `KeptNoteSettings`),
/// each time the app comes into use, so the settings file never keeps
/// growing. Prunes by a listing that started after that.
final documentSettingsPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  // A listing that starts now: an older one may miss documents written
  // since, e.g. one just moved, and their settings would look like a gone
  // document's.
  final contents = await ref.read(folderContentsProvider.notifier).refresh();
  if (contents == null) return;
  await ref
      .read(documentSettingsProvider.notifier)
      .prune(contents, now: DateTime.now());
});
