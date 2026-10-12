/// The user's choice for one conflict copy.
///
/// Phase 0 has only pick-a-side. Later choices (merged text, keep both) are
/// added as further subclasses.
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
