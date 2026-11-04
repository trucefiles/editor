import 'package:truce_core/truce_core.dart';

/// Syncthing's conflict-copy file names:
/// `<base>.sync-conflict-<YYYYMMDD>-<HHMMSS>-<device ID><ext>`, e.g.
/// `todo.sync-conflict-20261003-134809-4I343AW.md` for `todo.md`.
///
/// The device-ID part is missing in names from old Syncthing versions.
/// Nested names (a conflict copy of a conflict copy, from old versions or
/// other tools) belong to the innermost main file, made at the last
/// marker's time, in the local time of the device that made it.
final class SyncthingConflictNames implements ConflictCopyNames {
  const SyncthingConflictNames();

  /// One or more markers between the base name and the extension, as
  /// Syncthing inserts them before the last `.`.
  static final _pattern = RegExp(
    r'^(.*?)((?:\.sync-conflict-\d{8}-\d{6}(?:-[A-Z0-9]{7})?)+)(\.[^.]*)?$',
  );

  static final _stamped = StampedCopyNames('sync-conflict');

  static final _time = RegExp(r'(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)');

  @override
  CopyName? parse(String fileName) {
    final match = _pattern.firstMatch(fileName);
    if (match == null) return null;
    final mainName = match[1]! + (match[3] ?? '');
    if (mainName.isEmpty) return null;
    return (mainName: mainName, createdAt: _parseTime(match[2]!));
  }

  /// Without the device-ID part, which only Syncthing knows. Syncthing
  /// syncs such a copy like any other file.
  @override
  String format(String mainName, DateTime at) => _stamped.format(mainName, at);

  static DateTime _parseTime(String markers) {
    final last = _time.allMatches(markers).last;
    int part(int group) => int.parse(last[group]!);
    return DateTime(part(1), part(2), part(3), part(4), part(5), part(6));
  }
}
