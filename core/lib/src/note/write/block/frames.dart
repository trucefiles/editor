import 'package:collection/collection.dart';

import '../../lines/line.dart';
import '../../tree/blocks.dart';

/// A container a written line is in: its part of the line's prefix.
sealed class Frame {
  Frame(this.id);

  final BlockId id;

  /// Its part of a line, [old] if the line was one: the old bytes where
  /// they still say the same, else written anew; nothing on a [lazy]
  /// line that lacked it. On a [blank] line, the writer trims what ends
  /// up at the line's end.
  String partOf(SourceLine? old, {required bool blank, required bool lazy});

  /// Its old part of [line], if the line has one.
  String? oldPartOf(SourceLine? line) => oldPartIn(line, id);
}

/// [line]'s containers' parts from [container]'s on, if it has one.
String? oldPartsFrom(SourceLine? line, BlockId container) => switch (line
    ?.prefix
    .firstWhereOrNull((part) => part.container == container)) {
  final part? => line!.text.substring(part.start, line.prefix.last.end),
  null => null,
};

/// [container]'s old part of [line], if the line has one.
String? oldPartIn(SourceLine? line, BlockId container) => switch (line?.prefix
    .where((part) => part.container == container)
    .firstOrNull) {
  final part? => line!.text.substring(part.start, part.end),
  null => null,
};

/// A block quote's `>`.
final class QuoteFrame extends Frame {
  QuoteFrame(super.id, {required this.mark});

  /// Its mark on a new line: `> ` or `>`.
  final String mark;

  @override
  String partOf(SourceLine? old, {required bool blank, required bool lazy}) =>
      oldPartOf(old) ?? (lazy && old != null ? '' : mark);
}

/// A list item: its marker on its first line, its indent on the others.
final class ItemFrame extends Frame {
  ItemFrame(
    super.id, {
    required this.marker,
    required this.emptyMarker,
    required this.indent,
    this.oldMarkerLine,
    this.keepsMarker = false,
    this.keepsIndent = false,
  });

  /// Its marker part, for its first line.
  final String marker;

  /// Its marker part for a first line that holds nothing else.
  final String emptyMarker;

  /// Its indent part, for its other lines.
  final String indent;

  /// The line its old marker was on, if it was an item.
  final LineId? oldMarkerLine;

  /// Whether its old marker bytes still say the same.
  final bool keepsMarker;

  /// Whether its old indent bytes still reach its content.
  final bool keepsIndent;

  /// Whether its first line is still to come.
  bool markerPending = true;

  @override
  String partOf(SourceLine? old, {required bool blank, required bool lazy}) {
    final oldPart = oldPartOf(old);
    final onOldMarkerLine = old != null && old.id == oldMarkerLine;
    if (markerPending) {
      markerPending = false;
      return onOldMarkerLine && keepsMarker
          ? oldPart!
          : (blank ? emptyMarker : marker);
    }
    if (blank) return oldPart ?? indent;
    // A blank line's old part may fall short of marks after it now.
    if (oldPart != null &&
        !onOldMarkerLine &&
        keepsIndent &&
        !_ownBlank(old!)) {
      return oldPart;
    }
    return oldPart == null && lazy && old != null ? '' : indent;
  }
}

/// How an item's marker is written: [indent] before it, the [marker],
/// [padding] after it, and its [box] (`[ ]`, `[x]`) if it has one.
final class MarkerStyle {
  const MarkerStyle({
    this.indent = '',
    required this.marker,
    this.padding = ' ',
    this.box,
  });

  /// The style [item] was written in.
  factory MarkerStyle.of(ItemBlock item) {
    final width = item.marker.toString().length;
    return MarkerStyle(
      indent: ' ' * item.markerColumn,
      marker: item.marker.toString(),
      padding:
          ' ' * (item.contentColumn - item.markerColumn - width).clamp(1, 4),
      box: switch (item.checked) {
        null => null,
        true => '[x]',
        false => '[ ]',
      },
    );
  }

  final String indent;
  final String marker;
  final String padding;
  final String? box;

  /// This style with [marker], the box [checked] says, and [indent] and
  /// [padding] if given.
  MarkerStyle withMarker(
    String marker, {
    required bool? checked,
    String? indent,
    String? padding,
  }) => MarkerStyle(
    indent: indent ?? this.indent,
    marker: marker,
    padding: padding ?? this.padding,
    box: switch (checked) {
      null => null,
      true => '[x]',
      false => '[ ]',
    },
  );

  /// The marker part of an item's first line; for an [empty] item the
  /// whole line, which keeps a box's space so that every reader takes
  /// the box.
  String part({required bool empty}) {
    final written = '$indent$marker$padding${box == null ? '' : '$box '}';
    return empty && box == null ? written.trimRight() : written;
  }

  /// The indent of the item's other lines: up to its content.
  String get continuation =>
      ' ' * (indent.length + marker.length + padding.length);
}

/// Whether [line] holds nothing after its containers' parts.
bool _ownBlank(SourceLine line) =>
    line.text.substring(line.prefix.lastOrNull?.end ?? 0).trim().isEmpty;
