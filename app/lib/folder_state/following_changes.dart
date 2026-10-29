import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folders_controller.dart';
import '../platform/app_activity.dart';
import '../refresh/refresh_settings.dart';
import '../settings/device_settings_controller.dart';
import '../sync_tool/base_folder_following.dart';
import 'folder_state_controller.dart';

final followingChangesProvider = AsyncNotifierProvider<FollowingChanges, void>(
  FollowingChanges.new,
);

/// Passes what each base folder's changes hint on to the folder state
/// owner, as the refresh setting asks, while the app is in use, and tells
/// it whether the app is in use; the owner decides what to list or check.
///
/// Also lists every base folder once when the refresh setting changes,
/// for changes made while nothing was looking. Changes made while the app
/// was not in use are the screens' to catch up on, as they do in every
/// mode.
class FollowingChanges extends AsyncNotifier<void> {
  RefreshSettings? _lastSettings;

  @override
  Future<void> build() async {
    final owner = ref.watch(folderStateOwnerProvider);
    final subscriptions = <StreamSubscription<ChangeHint>>[];
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
    owner.send(Active(active: active));
    final settings = ref.watch(
      deviceSettingsProvider.select((s) => s.requireValue.refresh),
    );
    final settingChanged = _lastSettings != null && _lastSettings != settings;
    _lastSettings = settings;
    if (settingChanged) {
      unawaited(ref.read(folderContentsProvider.notifier).refresh());
    }
    if (!active) return;
    final folders = await ref.watch(foldersProvider.future);
    if (disposed) return;
    final bases = {for (final folder in folders) folder.base};
    final changes = await Future.wait([
      for (final base in bases)
        ref
            .watch(folderChangesProvider(base).future)
            .then((changes) => (base: base, changes: changes)),
    ]);
    if (disposed) return;
    for (final (:base, :changes) in changes) {
      if (changes == null) continue;
      subscriptions.add(
        changes.changes.listen((hint) => owner.send(Hinted(base.id, hint))),
      );
    }
  }
}
