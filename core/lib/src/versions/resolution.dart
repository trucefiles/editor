import 'dart:typed_data';

/// The user's choice between a file's current version and another one,
/// e.g. a conflict copy or a backup.
///
/// Pick a side, or keep both merged into one by the file's type.
sealed class Resolution {
  const Resolution();
}

/// Keep the main file and drop the copy.
/// For an orphaned conflict: discard the copy.
final class KeepCurrent extends Resolution {
  const KeepCurrent();
}

/// Replace the main file with the copy.
/// For an orphaned conflict: restore the copy as the main file.
final class KeepOther extends Resolution {
  const KeepOther();
}

/// Replace the main file with both versions merged into [bytes], as the
/// file's type merged them.
final class KeepMerged extends Resolution {
  const KeepMerged(this.bytes);

  final Uint8List bytes;
}
