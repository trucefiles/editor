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
    return switch (_head(value.substring(0, slash))) {
      (:final savedAt, :final kind) => Backup._(
        storePath,
        notePath: RelPath.parse(value.substring(slash + 1))!,
        savedAt: savedAt,
        kind: kind,
      ),
      null => null,
    };
  }

  /// When the backups in the store's top folder [name] were saved; `null`
  /// if it holds no backups.
  static DateTime? savedAtOfFolder(String name) => _head(name)?.savedAt;

  /// The time and kind in a backup's top folder [name],
  /// `<time in µs since epoch>.<kind>`.
  static ({DateTime savedAt, BackupKind kind})? _head(String name) {
    final parts = name.split('.');
    if (parts.length != 2) return null;
    final micros = int.tryParse(parts[0]);
    final kind = BackupKind._ofTag(parts[1]);
    if (micros == null || kind == null) return null;
    return (
      savedAt: DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true),
      kind: kind,
    );
  }

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
