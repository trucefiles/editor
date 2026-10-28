import 'package:truce_core/truce_core.dart';

import 'fake_copy_names.dart';

/// A made-up sync tool's file-name rules for tests of generic code: its
/// own folder is `.fake`, its temp files end in `.fake-tmp`, and its
/// conflict copies are named by [FakeCopyNames] (or kept out of the folder,
/// [FakeConflictSource]).
final class FakeSyncAdapter {
  const FakeSyncAdapter();

  static const _folder = '.fake';
  static const _tempSuffix = '.fake-tmp';

  /// Whether [path] belongs to the sync tool itself (folder markers,
  /// version folders, temp files, conflict copies): never shown.
  bool isInternal(RelPath path) =>
      isInternalFolder(path.value.split('/')) ||
      path.name.endsWith(_tempSuffix) ||
      const FakeCopyNames().parse(path.name) != null;

  /// Whether the folder with the segments [names], outermost first, is
  /// the tool's own or lies inside it.
  bool isInternalFolder(List<String> names) => names.contains(_folder);

  /// The temp file name of an atomic write; [randomToken] keeps
  /// concurrent writes apart.
  String tempFileName(String randomToken) => '$randomToken$_tempSuffix';
}
