/// Identifies a line of a document while it lives: edits keep it on the line
/// they change, so an editor can follow a line while its text changes.
/// Opaque: only equal or not.
extension type const LineId(int _value) {}

/// One line of a document: its text as in the file, without its line break.
final class Line {
  const Line(this.id, this.text);

  final LineId id;
  final String text;

  /// Whether the line is empty or only spaces and tabs.
  bool get isBlank => text.trim().isEmpty;

  /// This line with [text] instead, under the same id.
  Line withText(String text) => Line(id, text);

  @override
  bool operator ==(Object other) =>
      other is Line && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);

  @override
  String toString() => 'Line($id, $text)';
}
