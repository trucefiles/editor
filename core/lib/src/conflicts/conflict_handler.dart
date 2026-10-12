import 'dart:typed_data';

/// Conflict logic for one file type (e.g. Markdown, later KeePass).
/// Pure: bytes in, outcome out; knows no paths, no file access, no UI.
///
/// Which handler serves which `FileType` is wired outside, by the
/// `ConflictService`. Phase 0 has no handlers: every type falls back to
/// [NeedsUser]. Phase 1 adds a Markdown handler that merges todo lists.
abstract interface class ConflictHandler {
  /// Tries to merge [current] (main file) and [other] (conflict copy).
  /// Must be deterministic: same inputs, byte-identical output.
  MergeOutcome merge(Uint8List current, Uint8List other);
}

sealed class MergeOutcome {
  const MergeOutcome();
}

final class Merged extends MergeOutcome {
  const Merged(this.bytes);

  final Uint8List bytes;
}

/// No safe automatic merge; the user decides.
final class NeedsUser extends MergeOutcome {
  const NeedsUser();
}
