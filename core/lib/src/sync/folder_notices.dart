/// What the user should know about one folder, as its sync tool sees it,
/// e.g. that the tool may not sync it.
///
/// One implementation per sync tool, built for one folder; which notices
/// it gives, and how it finds out, is its own business.
abstract interface class FolderNotices {
  Future<List<FolderNotice>> check();
}

/// One thing to tell the user about a folder. Sync-tool neutral: the app
/// words each kind.
sealed class FolderNotice {
  const FolderNotice();

  /// Whether the user should act on it; otherwise it only informs.
  bool get isWarning;
}

/// The sync tool does not sync the folder: changes likely stay on this
/// device.
final class NotSyncedNotice extends FolderNotice {
  const NotSyncedNotice();

  @override
  bool get isWarning => true;
}

/// Whether the sync tool syncs the folder could not be checked, e.g. the
/// app can't see enough of the device.
final class SyncUnknownNotice extends FolderNotice {
  const SyncUnknownNotice();

  @override
  bool get isWarning => false;
}

/// Changes can't be followed live in this folder; it is checked for
/// changes every [interval] instead.
final class PolledNotice extends FolderNotice {
  const PolledNotice(this.interval);

  final Duration interval;

  @override
  bool get isWarning => false;

  @override
  bool operator ==(Object other) =>
      other is PolledNotice && other.interval == interval;

  @override
  int get hashCode => interval.hashCode;
}
