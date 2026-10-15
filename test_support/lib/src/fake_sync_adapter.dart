import 'package:truce_core/truce_core.dart';

/// A made-up sync tool's file-name rules for tests of generic code: its
/// own folder is `.fake`, its temp files end in `.fake-tmp`, and it keeps
/// conflict copies out of the folder ([FakeConflictSource]).
final class FakeSyncAdapter implements SyncAdapter {
  const FakeSyncAdapter();

  static const _folder = '.fake';
  static const _tempSuffix = '.fake-tmp';

  @override
  String get name => 'Fake sync';

  @override
  bool isInternal(RelPath path) =>
      isInternalFolder(path.value.split('/')) ||
      path.name.endsWith(_tempSuffix);

  @override
  bool isInternalFolder(List<String> names) => names.contains(_folder);

  @override
  String tempFileName(String randomToken) => '$randomToken$_tempSuffix';
}
