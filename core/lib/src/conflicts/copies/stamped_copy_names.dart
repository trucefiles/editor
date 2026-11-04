import 'conflict_copy_names.dart';

/// Conflict-copy names that put a [marker] and the time the copy was made
/// between a file's base name and its extension:
/// `<base>.<marker>-<YYYYMMDD>-<HHMMSS><ext>`, e.g.
/// `todo.my-copy-20261003-134809.md` for `todo.md`, in local time.
base class StampedCopyNames implements ConflictCopyNames {
  StampedCopyNames(this.marker)
    : _pattern = RegExp(
        '^(.*?)\\.${RegExp.escape(marker)}-'
        r'(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(\.[^.]*)?$',
      );

  /// What tells the copy apart, e.g. `my-copy`.
  final String marker;

  final RegExp _pattern;

  @override
  CopyName? parse(String fileName) {
    final match = _pattern.firstMatch(fileName);
    if (match == null || match[1]!.isEmpty) return null;
    int part(int group) => int.parse(match[group]!);
    return (
      mainName: match[1]! + (match[8] ?? ''),
      createdAt: DateTime(part(2), part(3), part(4), part(5), part(6), part(7)),
    );
  }

  @override
  String format(String mainName, DateTime at) {
    final dot = mainName.lastIndexOf('.');
    final (base, extension) = dot > 0
        ? (mainName.substring(0, dot), mainName.substring(dot))
        : (mainName, '');
    String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
    final date = '${pad(at.year, 4)}${pad(at.month)}${pad(at.day)}';
    final time = '${pad(at.hour)}${pad(at.minute)}${pad(at.second)}';
    return '$base.$marker-$date-$time$extension';
  }
}
