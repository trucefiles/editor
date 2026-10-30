import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:truce_markdown/truce_markdown.dart';

import '../document_metrics.dart';
import '../document_text_styles.dart';
import '../ui/document_image.dart';

/// The document's [text] to read, formatted by a standard CommonMark +
/// GitHub renderer, as it is in the file: items in their place, lines
/// without a blank line between them joined, front matter left out; text
/// sized as in the editor ([DocumentTextStyles]). Only shows: it offers no
/// actions on the document. Links open with [onLink]; images show as
/// [images] finds them.
class ReadView extends StatelessWidget {
  const ReadView(
    this.text, {
    required this.onLink,
    required this.images,
    super.key,
  });

  final String text;
  final void Function(String url) onLink;
  final DocumentImages images;

  @override
  Widget build(BuildContext context) => SelectionArea(
    // Selectable as a whole: text selectable block by block would make
    // each block a scroll view of its own, which takes the page's drags.
    child: Markdown(
      data: textAfterFrontMatter(text),
      extensionSet: md.ExtensionSet.gitHubWeb,
      styleSheet: _styleSheet(Theme.of(context), DocumentMetrics.of(context)),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      onTapLink: (_, href, _) {
        if (href != null) onLink(href);
      },
      imageBuilder: (uri, _, alt) =>
          DocumentImage(uri.toString(), alt: alt ?? '', images: images),
    ),
  );
}

/// The renderer's own sheet for [theme] (its colors), with the sizes of a
/// document's text: its body text wherever the renderer uses body text, code
/// and headings as the editor draws them; spaced by [metrics], so lines
/// stand as close as in the editors. Lists and checkboxes look as the
/// renderer draws them.
MarkdownStyleSheet _styleSheet(ThemeData theme, DocumentMetrics metrics) {
  final body = DocumentTextStyles.body(theme);
  final sheet = MarkdownStyleSheet.fromTheme(
    theme.copyWith(textTheme: theme.textTheme.copyWith(bodyMedium: body)),
  );
  final below = EdgeInsets.only(bottom: metrics.paragraphGap);
  return sheet.copyWith(
    code: sheet.code?.merge(DocumentTextStyles.code(body)),
    h1: DocumentTextStyles.heading(body, 1),
    h2: DocumentTextStyles.heading(body, 2),
    h3: DocumentTextStyles.heading(body, 3),
    h4: DocumentTextStyles.heading(body, 4),
    h5: DocumentTextStyles.heading(body, 5),
    h6: DocumentTextStyles.heading(body, 6),
    // The renderer's own box, in the theme's color, so it shows in dark
    // mode too.
    checkbox: sheet.checkbox?.copyWith(color: theme.colorScheme.primary),
    blockSpacing: metrics.blockGap,
    pPadding: below,
    h1Padding: below,
    h2Padding: below,
    h3Padding: below,
    h4Padding: below,
    h5Padding: below,
    h6Padding: below,
  );
}
