import 'package:truce_core/truce_core.dart';

import 'fake_copy_names.dart';

/// A made-up sync tool's file-name rules for tests of generic code: its
/// own folder is `.fake`, its temp files end in `.fake-tmp`, and its
/// conflict copies are named by [FakeCopyNames] (or kept out of the folder,
/// [FakeConflictSource]).
final class FakeSyncAdapter implements SyncAdapter {
  const FakeSyncAdapter();

  static const _folder = '.fake';
  static const _tempSuffix = '.fake-tmp';

  @override
  String get name => 'Fake sync';

  @override
  bool isInternal(RelPath path) =>
      isInternalFolder(path.value.split('/')) ||
      path.name.endsWith(_tempSuffix) ||
      const FakeCopyNames().parse(path.name) != null;

  @override
  bool isInternalFolder(List<String> names) => names.contains(_folder);

  @override
  String tempFileName(String randomToken) => '$randomToken$_tempSuffix';
}
