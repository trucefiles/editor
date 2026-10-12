import 'dart:typed_data';

import '../storage/rel_path.dart';

/// Conflict logic for one file type (e.g. Markdown, later KeePass).
/// Pure: bytes in, outcome out; no file access, no UI.
///
/// Phase 0 has a single fallback handler that always returns [NeedsUser].
/// Phase 1 adds a Markdown handler that merges todo lists.
abstract interface class ConflictHandler {
  /// Whether this handler is responsible for files at [path].
  bool accepts(RelPath path);

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
