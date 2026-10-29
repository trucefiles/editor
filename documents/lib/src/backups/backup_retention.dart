/// How long backups are kept.
const backupRetention = Duration(days: 7);

/// Tells that both versions are backed up before one is kept.
final bothBackedUp =
    'A backup of both stays on this device for '
    '${backupRetention.inDays} days.';
