import 'package:truce_core/truce_core.dart';

/// The app's own conflict-copy names in a plain folder:
/// `<base>.truce-conflict-<YYYYMMDD>-<HHMMSS><ext>`, e.g.
/// `todo.truce-conflict-20261003-134809.md` for `todo.md`. A save that
/// can't land is kept as such a copy, next to its document, in local time.
final class PlainConflictNames implements ConflictCopyNames {
  const PlainConflictNames();

  static const _marker = '.truce-conflict-';

  static final _pattern = RegExp(
    r'^(.*?)\.truce-conflict-(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(\.[^.]*)?$',
  );

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
    return '$base$_marker$date-$time$extension';
  }
}
