/// How a note is shown in the editor.
enum NoteView {
  /// Plain text, editable.
  text,

  /// Checkbox items, editable one by one.
  list,

  /// Markdown rendered for reading.
  rendered,
}
