import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// The app's look for rendered Markdown: the package default, with
/// checkboxes in the theme's primary color. The default paints them in the
/// background color in dark themes, so they vanish.
MarkdownStyleSheet markdownStyle(ThemeData theme) {
  final base = MarkdownStyleSheet.fromTheme(theme);
  return base.copyWith(
    checkbox: base.checkbox!.copyWith(color: theme.colorScheme.primary),
  );
}
