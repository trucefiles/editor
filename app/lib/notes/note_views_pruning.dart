import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_activity.dart';
import '../scan/folder_scans_controller.dart';
import 'note_views_controller.dart';

/// Forgets the saved views of notes that are gone, e.g. deleted or renamed
/// outside the app, each time the app comes into use, so the views file
/// never keeps growing.
final noteViewsPruningProvider = FutureProvider<void>((ref) async {
  if (!ref.watch(appActiveProvider)) return;
  final scans = await ref.read(folderScansProvider.future);
  await ref.read(noteViewsProvider.notifier).prune(scans);
});
