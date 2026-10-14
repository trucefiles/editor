/// A '/'-separated path relative to the root of a `FileStore`.
///
/// Never absolute, never empty, no empty, '.' or '..' segments.
extension type const RelPath._(String value) {
  /// Returns `null` if [raw] breaks any of the rules above.
  static RelPath? parse(String raw) {
    if (raw.isEmpty || raw.startsWith('/')) return null;
    final valid = raw
        .split('/')
        .every(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        );
    return valid ? RelPath._(raw) : null;
  }

  /// Last segment, e.g. `todo.md` for `lists/todo.md`.
  String get name => value.substring(value.lastIndexOf('/') + 1);

  /// The folder this path is in, e.g. `lists/work` for
  /// `lists/work/todo.md`; `null` at the root.
  RelPath? get parent {
    final slash = value.lastIndexOf('/');
    return slash < 0 ? null : RelPath._(value.substring(0, slash));
  }

  /// The path of [name] in the same folder, e.g. `lists/done.md` for
  /// `lists/todo.md` and `done.md`. `null` if [name] is not a valid name.
  RelPath? sibling(String name) {
    if (name.contains('/')) return null;
    return parse(value.substring(0, value.lastIndexOf('/') + 1) + name);
  }
}
