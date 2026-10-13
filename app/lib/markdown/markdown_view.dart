import 'package:flutter/material.dart';

import 'markdown_renderer.dart';

/// [markdown] rendered for reading; text can be selected and copied.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final blocks = MarkdownRenderer(Theme.of(context)).render(markdown);
    return SelectionArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          for (final block in blocks)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: block),
        ],
      ),
    );
  }
}
