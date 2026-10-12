/// A '/'-separated path relative to the root of a `FileStore`.
///
/// Never absolute, never empty, no '.' or '..' segments.
extension type const RelPath(String value) {
  /// Last segment, e.g. `todo.md` for `lists/todo.md`.
  String get name => value.substring(value.lastIndexOf('/') + 1);
}
