import '../conflicts/conflict.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'syncthing_conflict_name.dart';

/// The conflicts among [entries], found by Syncthing's conflict-copy names
/// next to their main file. Only conflicts whose main file [includesFile]
/// are kept. A copy's id is its path.
List<Conflict> groupSyncthingConflicts(
  List<FileEntry> entries,
  bool Function(RelPath file) includesFile,
) {
  final mains = {for (final entry in entries) entry.path: entry};
  final copiesByMain = <RelPath, List<ConflictCopy>>{};
  for (final entry in entries) {
    final name = SyncthingConflictName.parse(entry.path.name);
    if (name == null) continue;
    final mainPath = syncthingConflictMain(entry.path);
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

/// The main file that [path] is a Syncthing conflict copy of; `null` if it
/// is not a conflict copy.
RelPath? syncthingConflictMain(RelPath path) =>
    switch (SyncthingConflictName.parse(path.name)) {
      final name? => path.sibling(name.mainName),
      null => null,
    };
