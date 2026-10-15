import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/debouncer.dart';
import '../folders/folders_controller.dart';
import '../platform/app_activity.dart';
import '../refresh/refresh_settings.dart';
import '../refresh/refresh_settings_controller.dart';
import '../sync_tool/folder_services.dart';
import 'folder_scans_controller.dart';

final autoRescanProvider = AsyncNotifierProvider<AutoRescan, void>(
  AutoRescan.new,
);

/// Rescans when a folder's files change, as the refresh setting asks, while
/// the app is in use. Changes that come close together, like a sync of
/// many files, lead to one rescan.
///
/// Also rescans once when the refresh setting changes, for changes made
/// while nothing was looking. Changes made while the app was not in use
/// are the screens' to catch up on, as they do in every mode.
class AutoRescan extends AsyncNotifier<void> {
  /// How long changes must pause before a rescan.
  static const settleTime = Duration(milliseconds: 500);

  /// The longest a rescan waits while changes keep coming.
  static const maxWait = Duration(seconds: 3);

  RefreshSettings? _lastSettings;

  @override
  Future<void> build() async {
    final subscriptions = <StreamSubscription<RelPath>>[];
    final rescanSoon = Debouncer(_rescan, settle: settleTime, maxWait: maxWait);
    ref.onDispose(() {
      rescanSoon.cancel();
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    final active = ref.watch(appActiveProvider);
    final settings = await ref.watch(refreshSettingsProvider.future);
    final settingChanged = _lastSettings != null && _lastSettings != settings;
    _lastSettings = settings;
    if (settingChanged) _rescan();
    if (!active) return;
    final folders = await ref.watch(foldersProvider.future);
    final changes = await Future.wait([
      for (final folder in folders)
        ref.watch(folderChangesProvider(folder.location).future),
    ]);
    if (!ref.mounted) return;
    for (final folderChanges in changes.nonNulls) {
      subscriptions.add(folderChanges.changes.listen((_) => rescanSoon()));
    }
  }

  void _rescan() => unawaited(ref.read(folderScansProvider.notifier).refresh());
}
