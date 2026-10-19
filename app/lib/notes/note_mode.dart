/// How a note is shown in the editor.
enum NoteMode {
  /// Formatted, with Markdown marks hidden; editable, with checklist
  /// extras.
  visual,

  /// Every character, Markdown marks dimmed; editable as raw text.
  markdown,

  /// Formatted, as [visual]; not editable at all.
  read;

  /// The mode of a note with no last mode: [visual] for a checklist and
  /// a new note the user is [typing] in right away, else [read].
  static NoteMode first({required bool hasItems, required bool typing}) =>
      hasItems || typing ? visual : read;

  /// Whether the note's text can be edited in this mode.
  bool get edits => this != read;
}
