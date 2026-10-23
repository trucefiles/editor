import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'note_text_styles.dart';

/// The sizes around a note's text: gaps between lines, indents, the slots
/// of an item's row. They grow with the note's text, so the layout keeps
/// its proportions at any text size. Where the theme pads tap targets for
/// touch, item rows are at least a touch target high and their drag
/// handles wider, so a finger hits the one it means.
@immutable
final class NoteMetrics {
  const NoteMetrics({
    required this.scale,
    required this.touch,
    required this.lineHeight,
  });

  /// The metrics for the note text in [context]: as large as its text
  /// scaler shows body text.
  factory NoteMetrics.of(BuildContext context) {
    final theme = Theme.of(context);
    final body = NoteTextStyles.body(theme);
    final size = NoteTextStyles.sizeOf(body);
    final scaler = MediaQuery.textScalerOf(context);
    return NoteMetrics(
      scale: scaler.scale(size) / size,
      touch: theme.materialTapTargetSize == MaterialTapTargetSize.padded,
      lineHeight: NoteTextStyles.lineHeightOf(body, scaler),
    );
  }

  /// How many times its base size the note's text shows.
  final double scale;

  /// Whether the note is used by touch.
  final bool touch;

  /// The height of a line of body text.
  final double lineHeight;

  /// Space above and below a line of text.
  double get lineGap => 2 * scale;

  /// Space between the lines of two items in a list, the same in every
  /// mode; for fingers, at least so wide that a row with one line is a
  /// touch target high.
  double get itemGap => touch
      ? math.max(_itemGap, kMinInteractiveDimension - lineHeight)
      : _itemGap;

  double get _itemGap => 8 * scale;

  /// Space an item's row adds above and below its first line, inside the
  /// row, so its drag handle reaches over it: with the gaps of its line,
  /// items stand [itemGap] apart.
  double get itemRowInset => itemGap / 2 - lineGap;

  /// Space between blocks, and so between items, where a renderer lays
  /// them out (Read).
  double get blockGap => itemGap;

  /// Space a paragraph or heading adds below it there, so blocks stand
  /// about a blank line apart, as in the editors.
  double get paragraphGap => 28 * scale - blockGap;

  /// Indent of an item's text under the items it is in, per level.
  double get levelIndent => 28 * scale;

  /// Width before an item's marker, where its drag handle sits.
  double get handleWidth => (touch ? 48 : 24) * scale;

  /// Size of an item's drag handle icon, drawn in the middle of its
  /// width.
  double get handleIconSize => 20 * scale;

  /// Width of an item's box, bullet or number.
  double get markerWidth => 36 * scale;

  /// Space between a marker and its item's text.
  double get markerGap => 12 * scale;

  /// Indent of a quote's text, right of its bar.
  double get quoteIndent => 12 * scale;

  @override
  bool operator ==(Object other) =>
      other is NoteMetrics &&
      other.scale == scale &&
      other.touch == touch &&
      other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(scale, touch, lineHeight);
}
