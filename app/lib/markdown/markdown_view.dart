import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'markdown_links.dart';
import 'markdown_style.dart';

/// [markdown] rendered for reading; text can be selected and copied, links
/// open on tap.
class MarkdownView extends ConsumerWidget {
  const MarkdownView(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Markdown(
    data: markdown,
    styleSheet: markdownStyle(Theme.of(context)),
    selectable: true,
    // Keep line breaks as typed, as notes apps do.
    softLineBreak: true,
    onTapLink: (_, href, _) => openMarkdownLink(context, ref, href),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
    // Pulls down even when the text fits, to refresh.
    physics: const AlwaysScrollableScrollPhysics(),
  );
}
