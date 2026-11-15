/// How long backups are kept at most.
const backupRetention = Duration(days: 7);

/// How much space this device's backups may take, a setting: beyond it,
/// older backups go before [backupRetention] ends (see `overSpaceLimit`).
enum BackupSpace {
  mb50(50),
  mb100(100),
  mb250(250),
  mb500(500),
  noLimit(null);

  const BackupSpace(this.megabytes);

  /// What a device starts with.
  static const standard = mb100;

  /// The limit in megabytes; `null` for no limit.
  final int? megabytes;

  /// The limit in bytes; `null` for no limit.
  int? get bytes => switch (megabytes) {
    final megabytes? => megabytes * 1000 * 1000,
    null => null,
  };
}
