import 'package:truce_core/truce_core.dart';

/// User-facing text for why a backup was made.
extension BackupKindText on BackupKind {
  String get text => switch (this) {
    BackupKind.beforeEdit => 'Before editing',
    BackupKind.current => 'Before keeping a version: the file',
    BackupKind.other => 'Before keeping a version: the other one',
  };
}
