import '../backups/file_backups.dart';
import 'local_file_store.dart';

/// The backups in the app storage folder at [path], which is created
/// with the first backup.
///
/// App storage is private to this device and no sync tool sees it, so its
/// temp files follow the app's own naming, not a sync tool's.
FileBackups fileBackupsAt(String path) => FileBackups(
  LocalFileStore(path, _tempFileName, createsRoot: true),
  ignores: (file) => _isTempFile(file.name),
);

const _tempPrefix = '.truce-';
const _tempSuffix = '.tmp';

String _tempFileName(String randomToken) =>
    '$_tempPrefix$randomToken$_tempSuffix';

/// A temp file of an atomic write cut short, e.g. by a crash.
bool _isTempFile(String name) =>
    name.startsWith(_tempPrefix) && name.endsWith(_tempSuffix);
