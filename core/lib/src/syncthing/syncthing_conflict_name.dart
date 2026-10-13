/// Syncthing's conflict-copy file names:
/// `<base>.sync-conflict-<YYYYMMDD>-<HHMMSS>-<device ID><ext>`, e.g.
/// `todo.sync-conflict-20261003-134809-4I343AW.md` for `todo.md`.
///
/// The device-ID part is missing in names from old Syncthing versions.
/// Nested names (a conflict copy of a conflict copy, from old versions or
/// other tools) belong to the innermost main file.
final class SyncthingConflictName {
  const SyncthingConflictName._(this.mainName, this.createdAt);

  /// Parses a file name; `null` if it is not a conflict copy.
  static SyncthingConflictName? parse(String fileName) {
    final match = _pattern.firstMatch(fileName);
    if (match == null) return null;
    final mainName = match[1]! + (match[3] ?? '');
    if (mainName.isEmpty) return null;
    return SyncthingConflictName._(mainName, _parseTime(match[2]!));
  }

  /// The name of a conflict copy of [mainName] made [at] (local time), in
  /// Syncthing's format without the device-ID part, which only Syncthing
  /// knows. Syncthing syncs such a copy like any other file.
  static String format(String mainName, DateTime at) {
    final dot = mainName.lastIndexOf('.');
    final (base, extension) = dot > 0
        ? (mainName.substring(0, dot), mainName.substring(dot))
        : (mainName, '');
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${at.year.toString().padLeft(4, '0')}${two(at.month)}${two(at.day)}';
    final time = '${two(at.hour)}${two(at.minute)}${two(at.second)}';
    return '$base.sync-conflict-$date-$time$extension';
  }

  /// One or more markers between the base name and the extension, as
  /// Syncthing inserts them before the last `.`.
  static final _pattern = RegExp(
    r'^(.*?)((?:\.sync-conflict-\d{8}-\d{6}(?:-[A-Z0-9]{7})?)+)(\.[^.]*)?$',
  );

  static final _time = RegExp(r'(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)');

  /// Name of the main file the copy belongs to.
  final String mainName;

  /// When the copy was made, in the local time of the device that made it
  /// (the last marker, for nested names).
  final DateTime createdAt;

  static DateTime _parseTime(String markers) {
    final last = _time.allMatches(markers).last;
    int part(int group) => int.parse(last[group]!);
    return DateTime(part(1), part(2), part(3), part(4), part(5), part(6));
  }
}
