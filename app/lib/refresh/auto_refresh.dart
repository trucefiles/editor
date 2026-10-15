import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';
import '../platform/app_activity.dart';
import '../scan/folder_scans_controller.dart';

final autoRefreshProvider = AsyncNotifierProvider<AutoRefresh, void>(
  AutoRefresh.new,
);

/// Rescans when a folder's files change, as the refresh setting asks, while
/// the app is in use. Changes that come close together, like a sync of
/// many files, lead to one rescan.
///
/// After the setting or the folders change, rescans once, for changes made
/// while nothing was looking.
class AutoRefresh extends AsyncNotifier<void> {
  /// How long to wait for more changes before rescanning.
  static const settleTime = Duration(milliseconds: 500);

  var _hasRun = false;

  @override
  Future<void> build() async {
    final subscriptions = <StreamSubscription<RelPath>>[];
    Timer? pending;
    var disposed = false;
    ref.onDispose(() {
      disposed = true;
      pending?.cancel();
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });
    if (!ref.watch(appActiveProvider)) return;
    final folders = await ref.watch(foldersProvider.future);
    final changes = await Future.wait([
      for (final folder in folders)
        ref.watch(folderChangesProvider(folder.location).future),
    ]);
    if (disposed) return;
    void rescanSoon(RelPath _) => pending ??= Timer(settleTime, () {
      pending = null;
      _rescan();
    });
    for (final folderChanges in changes.nonNulls) {
      subscriptions.add(folderChanges.changes.listen(rescanSoon));
    }
    if (_hasRun) _rescan();
    _hasRun = true;
  }

  void _rescan() => unawaited(ref.read(folderScansProvider.notifier).refresh());
}
