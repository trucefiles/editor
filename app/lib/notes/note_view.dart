/// How a note is shown in the editor.
enum NoteView {
  /// The file's text as is ("Source"), editable. Saved by name, so the
  /// name stays.
  text,

  /// Checkbox items, editable one by one.
  list,

  /// Markdown rendered for reading.
  rendered;

  /// The view of a note with no last view: a list if it [hasItems], else
  /// the source if the user is [typing] right away (a new note), else
  /// rendered for reading.
  static NoteView first({required bool hasItems, required bool typing}) =>
      hasItems ? list : (typing ? text : rendered);
}
