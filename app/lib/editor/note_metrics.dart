import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'note_text_styles.dart';

/// The sizes around a note's text: gaps between lines, indents, the slots
/// of an item's row. They grow with the note's text, so the layout keeps
/// its proportions at any text size. Where the theme pads tap targets for
/// touch, items stand further apart and their drag handles are wider, so
/// a finger hits the one it means.
@immutable
final class NoteMetrics {
  const NoteMetrics({required this.scale, required this.touch});

  /// The metrics for the note text in [context]: as large as its text
  /// scaler shows body text.
  factory NoteMetrics.of(BuildContext context) {
    final theme = Theme.of(context);
    final body = NoteTextStyles.sizeOf(NoteTextStyles.body(theme));
    return NoteMetrics(
      scale: MediaQuery.textScalerOf(context).scale(body) / body,
      touch: theme.materialTapTargetSize == MaterialTapTargetSize.padded,
    );
  }

  /// How many times its base size the note's text shows.
  final double scale;

  /// Whether the note is used by touch.
  final bool touch;

  /// Space above and below a line of text.
  double get lineGap => 2 * scale;

  /// Space between the lines of two items in a list, the same in every
  /// mode. For fingers, a fixed extra on top, so a row with one line of
  /// base size text is a touch target high; it never shrinks as the text
  /// grows.
  double get itemGap => 8 * scale + (touch ? _touchExtra : 0);

  static const _touchExtra = 18.0;

  /// Space an item's row adds above and below its first line, inside the
  /// row, so its drag handle reaches over it: with the gaps of its line,
  /// items stand [itemGap] apart.
  double get itemRowInset => itemGap / 2 - lineGap;

  /// Space between blocks, and so between items, where a renderer lays
  /// them out (Read).
  double get blockGap => itemGap;

  /// Space a paragraph or heading adds below it there, so blocks stand at
  /// least about a blank line apart, as in the editors; items stand
  /// [blockGap] apart, which may be more.
  double get paragraphGap => math.max(0, 28 * scale - blockGap);

  /// Space between two blocks a blank line parts (e.g. two paragraphs), the
  /// same in every mode.
  double get blankLine => blockGap + paragraphGap;

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
      other is NoteMetrics && other.scale == scale && other.touch == touch;

  @override
  int get hashCode => Object.hash(scale, touch);
}
