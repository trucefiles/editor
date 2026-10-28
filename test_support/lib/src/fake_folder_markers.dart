import 'package:truce_core/truce_core.dart';

/// [FolderMarkers] over made-up folders for tests: [levels] holds the
/// entry names of the base folder (first), then of each folder above it,
/// up to the file system root; `null` for a folder that can't be read.
final class FakeFolderMarkers implements FolderMarkers {
  const FakeFolderMarkers(this.levels, {this.seesParents = true});

  final List<Set<String>?> levels;

  @override
  final bool seesParents;

  @override
  Future<bool?> holds(String name, {int levelsUp = 0}) async {
    if (levelsUp > 0 && !seesParents) return null;
    if (levelsUp >= levels.length) return null;
    return levels[levelsUp]?.contains(name);
  }
}
