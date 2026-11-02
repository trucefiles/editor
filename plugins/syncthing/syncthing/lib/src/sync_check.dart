/// Tells whether the sync tool syncs one folder.
///
/// One implementation per sync tool, built for one folder. How it finds
/// out (marker files, the tool's database or API) is its own business.
abstract interface class SyncCheck {
  Future<SyncStatus> check();
}

enum SyncStatus {
  /// The sync tool syncs the folder.
  synced,

  /// The sync tool does not sync the folder: changes likely stay on this
  /// device.
  notSynced,

  /// The check could not tell, e.g. it could not see enough of the
  /// device.
  unknown,
}
