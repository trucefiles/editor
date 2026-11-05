/// One undo step of a file type's own ([S]): an edit, kept so that undo
/// can take it back and redo can make it again.
abstract interface class UndoableEdit<S> {
  /// This step with [next], made right after it as part of the same
  /// typing, taken in: one step that goes from this step's before to
  /// [next]'s after.
  S joined(S next);
}

/// An edit kept as what showed before it and after it, as values of the
/// file type's own ([V]): undo shows [before], redo shows [after].
final class ShownStep<V> implements UndoableEdit<ShownStep<V>> {
  const ShownStep(this.before, this.after);

  final V before;
  final V after;

  @override
  ShownStep<V> joined(ShownStep<V> next) => ShownStep(before, next.after);
}
