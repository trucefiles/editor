import 'package:super_editor/super_editor.dart';

/// Pastes text with Windows (`\r\n`) or old Mac (`\r`) line breaks as
/// lines: the library splits pasted text at `\n` only, and a `\r` left
/// in a line would end up in the file as a space.
EditCommand? pasteLines(Editor editor, EditRequest request) =>
    switch (request) {
      PasteEditorRequest(:final content, :final pastePosition)
          when content.contains('\r') =>
        PasteEditorCommand(
          content: content.replaceAll(_breaks, '\n'),
          pastePosition: pastePosition,
        ),
      _ => null,
    };

final _breaks = RegExp('\r\n?');
