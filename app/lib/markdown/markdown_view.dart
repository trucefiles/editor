import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'markdown_style.dart';

/// [markdown] rendered for reading; text can be selected and copied.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) => Markdown(
    data: markdown,
    styleSheet: markdownStyle(Theme.of(context)),
    selectable: true,
    // Keep line breaks as typed, as notes apps do.
    softLineBreak: true,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
  );
}
