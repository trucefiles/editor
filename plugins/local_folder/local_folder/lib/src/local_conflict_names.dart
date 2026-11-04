import 'package:truce_core/truce_core.dart';

/// The app's own conflict-copy names in a local folder:
/// `<base>.truce-conflict-<YYYYMMDD>-<HHMMSS><ext>`, e.g.
/// `todo.truce-conflict-20261003-134809.md` for `todo.md`. A save that
/// can't land is kept as such a copy, next to its file, in local time.
final class LocalConflictNames extends StampedCopyNames {
  LocalConflictNames() : super('truce-conflict');
}
