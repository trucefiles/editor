import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

/// What a listed [file] holds, as its version: read by [read] when it
/// shows, and drawn once per version.
ShownContent listedContent(
  ListedFile file,
  Future<Result<FileBytes, StoreError>> Function(ListedFile file) read,
) => ShownContent(
  versionStampOf(file),
  () async => switch (await read(file)) {
    Ok(:final value) => value.bytes,
    Err() => null,
  },
);
