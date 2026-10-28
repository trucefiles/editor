import '../../storage/file_store.dart';
import '../../storage/rel_path.dart';
import '../conflict.dart';
import 'conflict_copy_names.dart';

/// The conflicts among [entries], found by [names] next to their main
/// file. Only conflicts whose main file [includesFile] are kept. A copy's
/// id is its path.
List<Conflict> groupConflictCopies(
  List<FileEntry> entries,
  ConflictCopyNames names,
  bool Function(RelPath file) includesFile,
) {
  final mains = {for (final entry in entries) entry.path: entry};
  final copiesByMain = <RelPath, List<ConflictCopy>>{};
  for (final entry in entries) {
    final name = names.parse(entry.path.name);
    if (name == null) continue;
    final mainPath = entry.path.sibling(name.mainName);
    if (mainPath == null || !includesFile(mainPath)) continue;
    copiesByMain
        .putIfAbsent(mainPath, () => [])
        .add(
          ConflictCopy(
            id: entry.path.value,
            version: entry.version,
            createdAt: name.createdAt,
          ),
        );
  }
  return [
    for (final MapEntry(key: mainPath, value: copies) in copiesByMain.entries)
      Conflict(
        mainPath: mainPath,
        main: mains[mainPath],
        // File-name order: the timestamps in the names sort oldest first.
        copies: copies..sort((a, b) => a.id.compareTo(b.id)),
      ),
  ];
}

/// The main file that [path] is a conflict copy of, by [names]; `null` if
/// it is not a conflict copy.
RelPath? conflictCopyMain(RelPath path, ConflictCopyNames names) =>
    switch (names.parse(path.name)) {
      final name? => path.sibling(name.mainName),
      null => null,
    };
