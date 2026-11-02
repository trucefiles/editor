/// How the user marked one file for every device. Synced through
/// `FileMarks`.
final class FileMark {
  const FileMark({this.color});

  /// No color.
  static const none = FileMark();

  /// Name of a color the app offers, e.g. `teal`; `null` for none. A name,
  /// not a value, so each app picks shades that fit its theme.
  final String? color;

  bool get isNone => this == none;

  FileMark withColor(String? color) => FileMark(color: color);

  @override
  bool operator ==(Object other) => other is FileMark && other.color == color;

  @override
  int get hashCode => color.hashCode;
}
