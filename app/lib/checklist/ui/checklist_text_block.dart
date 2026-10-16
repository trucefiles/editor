import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../markdown/markdown_links.dart';
import '../../markdown/markdown_style.dart';

/// Lines between checkbox items (headings, notes), rendered as Markdown;
/// links open on tap.
class ChecklistTextBlock extends ConsumerWidget {
  const ChecklistTextBlock(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: MarkdownBody(
      data: markdown,
      styleSheet: markdownStyle(Theme.of(context)),
      softLineBreak: true,
      onTapLink: (_, href, _) => openMarkdownLink(context, ref, href),
    ),
  );
}
