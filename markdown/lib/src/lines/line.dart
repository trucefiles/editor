/// Identifies a line of a document while it lives: edits keep it on the line
/// they change, so an editor can follow a line while its text changes.
/// Opaque: only equal or not.
extension type const LineId(int _value) {}

/// One line of a document: its text as in the file, and the line ending
/// after it (`\n`, `\r\n` or `\r`; empty for the last line).
final class Line {
  const Line(this.id, this.text, [this.ending = '']);

  final LineId id;
  final String text;
  final String ending;

  /// Whether the line is empty or only spaces and tabs.
  bool get isBlank => text.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is Line &&
      other.id == id &&
      other.text == text &&
      other.ending == ending;

  @override
  int get hashCode => Object.hash(id, text, ending);

  @override
  String toString() => 'Line($id, $text)';
}
