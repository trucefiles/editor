/// What the editing keys do to a note, at the editor's selection: what a
/// text editor would do to text, done on the note's structure.
abstract interface class KeyActions {
  /// Enter: see `NoteDocumentController.enter`.
  void enter();

  /// A line break in the block: see `NoteDocumentController.lineBreak`.
  void lineBreak();

  /// Backspace at the start of node [nodeId].
  void joinBackward(String nodeId);

  /// Delete at the end of node [nodeId].
  void joinForward(String nodeId);

  /// Pastes [text] over the selection.
  void paste(String text);

  /// Replaces the text from [start] to [end] in node [nodeId] by [text].
  void replaceText(String nodeId, int start, int end, String text);

  /// Indents, or with [outdent] outdents, the item the caret is in;
  /// returns whether it is in one.
  bool indentAtCaret({required bool outdent});
}
