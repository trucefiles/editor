/// How the user marked one note. Synced through `NoteMarks`.
final class NoteMark {
  const NoteMark({this.pinned = false, this.color});

  /// Not pinned, no color.
  static const none = NoteMark();

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Name of a color the app offers, e.g. `teal`; `null` for none. A name,
  /// not a value, so each app picks shades that fit its theme.
  final String? color;

  bool get isNone => !pinned && color == null;

  NoteMark withPinned({required bool pinned}) =>
      NoteMark(pinned: pinned, color: color);

  NoteMark withColor(String? color) => NoteMark(pinned: pinned, color: color);

  @override
  bool operator ==(Object other) =>
      other is NoteMark && other.pinned == pinned && other.color == color;

  @override
  int get hashCode => Object.hash(pinned, color);
}
