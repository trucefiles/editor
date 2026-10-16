/// How the user marked one note for every device. Synced through
/// `NoteMarks`.
final class NoteMark {
  const NoteMark({this.color});

  /// No color.
  static const none = NoteMark();

  /// Name of a color the app offers, e.g. `teal`; `null` for none. A name,
  /// not a value, so each app picks shades that fit its theme.
  final String? color;

  bool get isNone => this == none;

  NoteMark withColor(String? color) => NoteMark(color: color);

  @override
  bool operator ==(Object other) => other is NoteMark && other.color == color;

  @override
  int get hashCode => color.hashCode;
}
