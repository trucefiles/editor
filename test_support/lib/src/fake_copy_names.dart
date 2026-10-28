import 'package:truce_core/truce_core.dart';

/// A made-up sync tool's conflict-copy names for tests of generic code:
/// `<base>.fake-copy-<YYYYMMDD>-<HHMMSS><ext>`, e.g.
/// `todo.fake-copy-20261003-134809.md` for `todo.md`.
final class FakeCopyNames implements ConflictCopyNames {
  const FakeCopyNames();

  static final _pattern = RegExp(
    r'^(.*?)\.fake-copy-(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(\.[^.]*)?$',
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
    return '$base.fake-copy-${pad(at.year, 4)}${pad(at.month)}${pad(at.day)}'
        '-${pad(at.hour)}${pad(at.minute)}${pad(at.second)}$extension';
  }
}
