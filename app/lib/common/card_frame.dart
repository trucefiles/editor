import 'dart:math';

import 'package:flutter/material.dart';
import 'package:truce_documents/truce_documents.dart' show DocumentCardSummary;

import '../text_zoom/ui/document_text_zoom.dart';

/// The frame every card in a document grid shares: the title and [body] at
/// the document text zoom, [footer] at the bottom; as tall as they are.
class CardFrame extends StatelessWidget {
  const CardFrame({
    required this.title,
    required this.footer,
    required this.onTap,
    this.body,
    this.onMark,
    this.color,
    this.shape,
    super.key,
  });

  final String title;

  /// Document text under the title, usually a [CardLines].
  final Widget? body;

  final Widget footer;
  final VoidCallback onTap;

  /// Asks for a pin or color: on long press, or right click with a mouse.
  final VoidCallback? onMark;

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
        onLongPress: onMark,
        onSecondaryTap: onMark,
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
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
    maxLines: DocumentCardSummary.previewLines,
    overflow: TextOverflow.ellipsis,
  );
}

/// Size of an icon in a card's footer.
const cardFooterIconSize = 18.0;

const _margin = 4.0;
const _padding = 12.0;
const _titleGap = 6.0;
const _footerGap = 8.0;

/// Fits a line of small labels, a label with a background or an icon.
double _footerHeight(BuildContext context) => max(
  cardFooterIconSize,
  _lineHeight(
        Theme.of(context).textTheme.labelSmall,
        MediaQuery.textScalerOf(context),
      ) +
      4,
);

double _lineHeight(TextStyle? style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
