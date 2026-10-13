import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

/// Turns a Markdown document into read-only widgets: headings, paragraphs,
/// lists with task checkboxes, quotes, code and rules, with bold, italic,
/// strikethrough, inline code and links inside. Anything else shows as its
/// plain text.
final class MarkdownRenderer {
  const MarkdownRenderer(this._theme);

  final ThemeData _theme;

  static const _blockTags = {
    'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', //
    'ul', 'ol', 'blockquote', 'pre', 'hr', 'table',
  };

  TextTheme get _text => _theme.textTheme;

  /// One widget per top-level block of [markdown].
  List<Widget> render(String markdown) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    return [for (final node in document.parse(markdown)) _block(node)];
  }

  Widget _block(md.Node node) {
    if (node is! md.Element) return _rich([node], _text.bodyMedium);
    return switch (node.tag) {
      'h1' => _rich(node.children, _text.headlineMedium),
      'h2' => _rich(node.children, _text.headlineSmall),
      'h3' => _rich(node.children, _text.titleLarge),
      'h4' || 'h5' || 'h6' => _rich(node.children, _text.titleMedium),
      'ul' || 'ol' => _list(node),
      'blockquote' => _quote(node),
      'pre' => _codeBlock(node.textContent),
      'hr' => const Divider(),
      'table' => Text(node.textContent, style: _text.bodyMedium),
      _ => _rich(node.children, _text.bodyMedium),
    };
  }

  Widget _rich(List<md.Node>? nodes, TextStyle? style) => Text.rich(
    TextSpan(
      style: style,
      children: [for (final n in nodes ?? const <md.Node>[]) _span(n)],
    ),
  );

  /// Children of a list item or quote: inline runs as paragraphs, blocks
  /// as blocks.
  List<Widget> _mixed(List<md.Node> nodes) {
    final widgets = <Widget>[];
    var run = <md.Node>[];
    void endRun() {
      if (run.isNotEmpty) widgets.add(_rich(run, _text.bodyMedium));
      run = [];
    }

    for (final node in nodes) {
      if (node is md.Element && _blockTags.contains(node.tag)) {
        endRun();
        widgets.add(_block(node));
      } else if (!_isTaskBox(node)) {
        run.add(node);
      }
    }
    endRun();
    return widgets;
  }

  Widget _list(md.Element list) {
    final items = list.children ?? const <md.Node>[];
    final start = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, item) in items.indexed)
          if (item is md.Element)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: _marker(
                    list.tag == 'ol' ? '${start + index}.' : null,
                    item,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _mixed(item.children ?? const []),
                  ),
                ),
              ],
            ),
      ],
    );
  }

  /// A checkbox for task items, else [number] or a bullet.
  Widget _marker(String? number, md.Element item) {
    final first = item.children?.firstOrNull;
    // Loose lists put the checkbox into the item's first paragraph.
    final candidates = first is md.Element && first.tag == 'p'
        ? first.children
        : item.children;
    final box = candidates?.where(_isTaskBox).firstOrNull;
    if (box is md.Element) {
      final checked = box.attributes['checked'] == 'true';
      return Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: 20,
      );
    }
    return Text(number ?? '•', style: _text.bodyMedium);
  }

  static bool _isTaskBox(md.Node node) =>
      node is md.Element &&
      node.tag == 'input' &&
      node.attributes['type'] == 'checkbox';

  Widget _quote(md.Element quote) => Container(
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: _theme.colorScheme.outlineVariant, width: 4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _mixed(quote.children ?? const []),
    ),
  );

  Widget _codeBlock(String code) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      code.trimRight(),
      style: _text.bodyMedium?.copyWith(fontFamily: 'monospace'),
    ),
  );

  InlineSpan _span(md.Node node) {
    if (node is! md.Element) return TextSpan(text: node.textContent);
    final children = [
      for (final child in node.children ?? const <md.Node>[]) _span(child),
    ];
    return switch (node.tag) {
      'strong' => TextSpan(
        style: const TextStyle(fontWeight: FontWeight.bold),
        children: children,
      ),
      'em' => TextSpan(
        style: const TextStyle(fontStyle: FontStyle.italic),
        children: children,
      ),
      'del' => TextSpan(
        style: const TextStyle(decoration: TextDecoration.lineThrough),
        children: children,
      ),
      'code' => TextSpan(
        text: node.textContent,
        style: TextStyle(
          fontFamily: 'monospace',
          backgroundColor: _theme.colorScheme.surfaceContainerHighest,
        ),
      ),
      'a' => TextSpan(
        style: TextStyle(
          color: _theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        children: children,
      ),
      'br' => const TextSpan(text: '\n'),
      // Task checkboxes are drawn as the list marker.
      'input' => const TextSpan(),
      'img' => TextSpan(text: node.attributes['alt'] ?? ''),
      _ => TextSpan(children: children),
    };
  }
}
