import 'package:truce_core/truce_core.dart';

/// User-facing text for why a backup was made.
extension BackupKindText on BackupKind {
  String get text => switch (this) {
    BackupKind.beforeEdit => 'The file before you edited it',
    BackupKind.beforeDelete => 'The file as you deleted it',
    BackupKind.current => 'The file before you resolved a conflict',
    BackupKind.other => 'The other side of a resolved conflict',
  };
}
