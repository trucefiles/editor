import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../markdown/markdown_style.dart';

/// Lines between checkbox items (headings, notes), rendered as Markdown.
class ChecklistTextBlock extends StatelessWidget {
  const ChecklistTextBlock(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: MarkdownBody(
      data: markdown,
      styleSheet: markdownStyle(Theme.of(context)),
      softLineBreak: true,
    ),
  );
}
