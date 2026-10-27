import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folders_controller.dart';
import '../platform/app_activity.dart';
import '../reach/folder_reach_controller.dart';
import '../refresh/refresh_settings.dart';
import '../refresh/refresh_settings_controller.dart';
import '../sync_tool/folder_services.dart';
import 'folder_scans_controller.dart';

final autoRescanProvider = AsyncNotifierProvider<AutoRescan, void>(
  AutoRescan.new,
);

/// Tells the scans owner when a folder's files change, as the refresh
/// setting asks, while the app is in use, and whether the app is in use;
/// the owner decides when to rescan.
///
/// Starts following a folder's changes afresh once the folder is reachable
/// again, so a folder that went away is watched again, not only polled.
///
/// Also tells it when the refresh setting changes, for changes made while
/// nothing was looking. Changes made while the app was not in use are the
/// screens' to catch up on, as they do in every mode.
class AutoRescan extends AsyncNotifier<void> {
  RefreshSettings? _lastSettings;

  @override
  Future<void> build() async {
    final scans = ref.watch(folderScansOwnerProvider);
    final subscriptions = <StreamSubscription<RelPath>>[];
    // This build's own end: `ref.mounted` speaks for the newest build, so
    // a build that a newer one replaced while it awaited must stop by this.
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    final active = ref.watch(appActiveProvider);
    scans.send(Active(active: active));
    final settings = await ref.watch(refreshSettingsProvider.future);
    if (disposed) return;
    final settingChanged = _lastSettings != null && _lastSettings != settings;
    _lastSettings = settings;
    if (settingChanged) scans.send(const SettingChanged());
    if (!active) return;
    final folders = await ref.watch(foldersProvider.future);
    if (disposed) return;
    // Follows again once a folder is back: watching ends when its folder
    // goes away, and goes on by polling until then.
    for (final folder in folders) {
      ref.watch(
        folderReachProvider(folder.location)
            .select((reach) => reach == Reach.reachable),
      );
    }
    final changes = await Future.wait([
      for (final folder in folders)
        ref.watch(folderChangesProvider(folder.location).future),
    ]);
    if (disposed) return;
    for (final folderChanges in changes.nonNulls) {
      subscriptions.add(
        folderChanges.changes.listen((_) => scans.send(const FilesChanged())),
      );
    }
  }
}
