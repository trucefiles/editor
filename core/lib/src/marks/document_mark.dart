/// How the user marked one document for every device. Synced through
/// `DocumentMarks`.
final class DocumentMark {
  const DocumentMark({this.color});

  /// No color.
  static const none = DocumentMark();

  /// Name of a color the app offers, e.g. `teal`; `null` for none. A name,
  /// not a value, so each app picks shades that fit its theme.
  final String? color;

  bool get isNone => this == none;

  DocumentMark withColor(String? color) => DocumentMark(color: color);

  @override
  bool operator ==(Object other) =>
      other is DocumentMark && other.color == color;

  @override
  int get hashCode => color.hashCode;
}
