import 'package:truce_core/truce_core.dart';

/// A made-up sync tool's conflict-copy names for tests of generic code:
/// `<base>.fake-copy-<YYYYMMDD>-<HHMMSS><ext>`, e.g.
/// `todo.fake-copy-20261003-134809.md` for `todo.md`.
final class FakeCopyNames extends StampedCopyNames {
  FakeCopyNames() : super('fake-copy');
}
