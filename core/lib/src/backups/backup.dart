import '../storage/rel_path.dart';

/// Why a backup of a note was made.
enum BackupKind {
  /// The note's file before the first save of an editing session.
  beforeEdit('edit'),

  /// The note's file before the user kept one of two versions.
  current('current'),

  /// The version that clashed with the note's file (a conflict copy,
  /// edits made from an older version, or a backup being restored).
  other('other');

  const BackupKind(this._tag);

  /// The kind's part of a backup's path.
  final String _tag;

  static BackupKind? _ofTag(String tag) {
    for (final kind in values) {
      if (kind._tag == tag) return kind;
    }
    return null;
  }
}

/// One backup of a note, in a backup store.
///
/// Kept at `<time in µs since epoch>.<kind>/<note path>`, e.g.
/// `1791818275000000.edit/lists/todo.md`: the note's path is kept whole,
/// so the backup knows where it belongs.
final class Backup {
  const Backup._(
    this.storePath, {
    required this.notePath,
    required this.savedAt,
    required this.kind,
  });

  /// A new backup of [notePath], saved [at] as [kind].
  Backup.of(this.notePath, {required DateTime at, required this.kind})
    : savedAt = at.toUtc(),
      storePath = RelPath.parse(
        '${at.microsecondsSinceEpoch}.${kind._tag}/${notePath.value}',
      )!;

  /// The backup kept at [storePath]; `null` if it is not one.
  static Backup? parse(RelPath storePath) {
    final value = storePath.value;
    final slash = value.indexOf('/');
    if (slash < 0) return null;
    final head = value.substring(0, slash).split('.');
    if (head.length != 2) return null;
    final savedAt = _time(head[0]);
    final kind = BackupKind._ofTag(head[1]);
    if (savedAt == null || kind == null) return null;
    return Backup._(
      storePath,
      notePath: RelPath.parse(value.substring(slash + 1))!,
      savedAt: savedAt,
      kind: kind,
    );
  }

  /// When the file at [storePath] was saved as a backup, also for backups
  /// in earlier layouts; `null` if it is no backup.
  static DateTime? savedAtOf(RelPath storePath) =>
      _time(storePath.value.split(RegExp('[./]')).first);

  static DateTime? _time(String micros) => switch (int.tryParse(micros)) {
    final micros? => DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
    null => null,
  };

  /// Where the backup is kept in its store.
  final RelPath storePath;

  /// The note it is a copy of, in the note's folder.
  final RelPath notePath;

  final DateTime savedAt;
  final BackupKind kind;

  @override
  bool operator ==(Object other) =>
      other is Backup && other.storePath == storePath;

  @override
  int get hashCode => storePath.hashCode;
}
