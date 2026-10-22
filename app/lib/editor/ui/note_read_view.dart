import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:truce_core/truce_core.dart';

import '../note_document_controller.dart';
import '../note_text_styles.dart';
import 'note_image.dart';

/// The open [note] to read, formatted by a standard CommonMark + GitHub
/// renderer, as it is in the file: items in their place, lines without a
/// blank line between them joined, front matter left out; text sized as
/// in the editor ([NoteTextStyles]). Links open with [onLink]; images show
/// as [images] finds them. Follows each change of the note.
class NoteReadView extends StatelessWidget {
  const NoteReadView(
    this.note, {
    required this.onLink,
    required this.images,
    super.key,
  });

  final NoteDocumentController note;
  final void Function(String url) onLink;
  final NoteImages images;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: note,
    // Selectable as a whole: text selectable block by block would make
    // each block a scroll view of its own, which takes the page's drags.
    builder: (context, _) => SelectionArea(
      child: Markdown(
        data: _withoutFrontMatter(note.document),
        extensionSet: md.ExtensionSet.gitHubWeb,
        styleSheet: _styleSheet(Theme.of(context)),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        onTapLink: (_, href, _) {
          if (href != null) onLink(href);
        },
        imageBuilder: (uri, _, alt) =>
            NoteImage(uri.toString(), alt: alt ?? '', images: images),
      ),
    ),
  );
}

/// The renderer's own sheet for [theme] (its colors and spacing), with
/// the sizes of a note's text: its body text wherever the renderer uses
/// body text, code and headings as the editor draws them.
MarkdownStyleSheet _styleSheet(ThemeData theme) {
  final body = NoteTextStyles.body(theme);
  final sheet = MarkdownStyleSheet.fromTheme(
    theme.copyWith(textTheme: theme.textTheme.copyWith(bodyMedium: body)),
  );
  return sheet.copyWith(
    code: sheet.code?.merge(NoteTextStyles.code(body)),
    h1: NoteTextStyles.heading(body, 1),
    h2: NoteTextStyles.heading(body, 2),
    h3: NoteTextStyles.heading(body, 3),
    h4: NoteTextStyles.heading(body, 4),
    h5: NoteTextStyles.heading(body, 5),
    h6: NoteTextStyles.heading(body, 6),
  );
}

/// The text of [document] after its front matter, if it has any.
String _withoutFrontMatter(MarkdownDocument document) =>
    switch (document.root.children.firstOrNull) {
      final FrontMatterBlock front =>
        document.lines
            .skip(front.lines.length)
            .map((line) => line.raw)
            .join('\n'),
      _ => document.text,
    };
