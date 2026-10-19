/// How a note is shown in the editor.
enum NoteMode {
  /// Formatted, with Markdown marks hidden but on the edited line;
  /// editable, with list extras.
  visual,

  /// Every character, Markdown marks dimmed; editable as plain text.
  markdown,

  /// Formatted, as [visual]; not editable at all.
  read;

  /// The mode of a note with no last mode: [visual] for a note with
  /// checkboxes and a new note the user is [typing] in right away, else
  /// [read].
  static NoteMode first({required bool hasCheckboxes, required bool typing}) =>
      hasCheckboxes || typing ? visual : read;

  /// Whether the note's text can be edited in this mode.
  bool get edits => this != read;
}
