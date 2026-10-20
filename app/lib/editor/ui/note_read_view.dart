import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../note_document_controller.dart';
import 'note_image.dart';

/// The open [note] to read, formatted by a standard CommonMark + GitHub
/// renderer, as it is in the file: items in their place, lines without a
/// blank line between them joined. Links open with [onLink]; images show
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
    builder: (context, _) => Markdown(
      data: note.document.text,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      onTapLink: (_, href, _) {
        if (href != null) onLink(href);
      },
      imageBuilder: (uri, _, alt) =>
          NoteImage(uri.toString(), alt: alt ?? '', images: images),
    ),
  );
}
