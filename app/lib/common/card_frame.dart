import 'dart:math';

import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_files/truce_files.dart' show FileCardSummary;

import '../text_zoom/ui/document_text_zoom.dart';

/// The frame every card in a file grid shares: the title, after
/// [leading] if given, and [body] at the document text zoom, [footer] at
/// the bottom; as tall as they are.
class CardFrame extends StatelessWidget {
  const CardFrame({
    required this.title,
    required this.footer,
    required this.onTap,
    this.leading,
    this.body,
    this.onActions,
    this.onActionsAt,
    this.color,
    this.shape,
    super.key,
  });

  final String title;

  /// Shown before the title, beside its first line, e.g. an icon; icons
  /// in it are as large as the title's letters, so they grow with them.
  final Widget? leading;

  /// Document text under the title, usually a [CardLines].
  final Widget? body;

  final Widget footer;
  final VoidCallback onTap;

  /// Asks for the card's actions on a long press.
  final VoidCallback? onActions;

  /// Asks for the card's actions on a right click, at its point on the
  /// screen.
  final ValueChanged<Offset>? onActionsAt;

  final Color? color;
  final ShapeBorder? shape;

  @override
  // A grid moves its cards as it scrolls; each repaints on its own.
  Widget build(BuildContext context) => RepaintBoundary(
    child: Card(
      margin: const EdgeInsets.all(_margin),
      clipBehavior: Clip.antiAlias,
      color: color,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        onLongPress: onActions,
        onSecondaryTapUp: switch (onActionsAt) {
          final onActionsAt? => (details) => onActionsAt(
            details.globalPosition,
          ),
          null => null,
        },
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DocumentTextZoom(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _titleGap,
                  children: [
                    _Title(title, leading: leading),
                    ?body,
                  ],
                ),
              ),
              const SizedBox(height: _footerGap),
              SizedBox(height: _footerHeight(context), child: footer),
            ],
          ),
        ),
      ),
    ),
  );
}

/// [title] in at most two lines, after [leading] if given, centered on
/// the first line and sized to its letters.
class _Title extends StatelessWidget {
  const _Title(this.title, {required this.leading});

  final String title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    final text = Text(
      title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final scaler = MediaQuery.textScalerOf(context);
    return switch (leading) {
      null => text,
      final leading => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _leadingGap,
        children: [
          SizedBox(
            height: lineHeightOf(style, scaler),
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(size: scaler.scale(style?.fontSize ?? 16)),
                child: leading,
              ),
            ),
          ),
          Flexible(child: text),
        ],
      ),
    };
  }
}

/// [text] in the cards' body style, in at most as many lines as a preview
/// has, the last one ending in "…" if more is left.
class CardLines extends StatelessWidget {
  const CardLines(this.text, {this.italic = false, super.key});

  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontStyle: italic ? FontStyle.italic : null),
    maxLines: FileCardSummary.previewLines,
    overflow: TextOverflow.ellipsis,
  );
}

/// Size of an icon in a card's footer.
const cardFooterIconSize = 18.0;

const _margin = 4.0;
const _padding = 12.0;
const _titleGap = 6.0;
const _leadingGap = 6.0;
const _footerGap = 8.0;

/// Fits a line of small labels, a label with a background or an icon.
double _footerHeight(BuildContext context) => max(
  cardFooterIconSize,
  lineHeightOf(
        Theme.of(context).textTheme.labelSmall,
        MediaQuery.textScalerOf(context),
      ) +
      4,
);
