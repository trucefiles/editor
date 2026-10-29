/// The marks a container writes on each line of what it holds: a
/// quote's `>`, an item's marker on its first line and indent on the
/// rest.
library;

import '../doc/doc_nodes.dart';
import '../tree/blocks.dart';

/// A container's part of the lines it holds.
sealed class Frame {
  Frame(this.node);

  final DocContainer node;

  /// The block it was read as, if its marks are still as read there:
  /// lines read in it keep their bytes for its part.
  Block? get kept;

  /// Its part of the next line, which is its first if [first].
  String part({required bool first});

  /// Its part of a line read as [line], if kept and the line has one
  /// that fits where it goes now; `null` if it must be written anew.
  String? keptPart(SourceLine line, {required bool first}) {
    final kept = this.kept;
    if (kept == null) return null;
    final part = line.prefix.where((part) => part.container == kept.id);
    // An empty part, as on a blank line, would leave out its marks.
    if (part.isEmpty || part.first.start == part.first.end) return null;
    if (kept is ItemBlock && (kept.markerLine == line.index) != first) {
      return null;
    }
    return line.text.substring(part.first.start, part.first.end);
  }
}

/// A quote's `> `.
final class QuoteFrame extends Frame {
  QuoteFrame(QuoteNode super.node);

  @override
  QuoteBlock? get kept => switch (node.source) {
    final QuoteBlock block => block,
    _ => null,
  };

  @override
  String part({required bool first}) => '> ';
}

/// An item's marker (and box) on its first line, and spaces as wide as
/// the marker on the rest.
final class ItemFrame extends Frame {
  ItemFrame(ItemNode super.node, {required this.marker, this.indentBelow = 4});

  /// Its marker: a bullet, or a number and its delimiter.
  final String marker;

  ItemNode get item => node as ItemNode;

  ItemBlock? get _source => switch (node.source) {
    final ItemBlock block => block,
    _ => null,
  };

  /// The column its marker must start before, to stay out of the item
  /// before it.
  final int indentBelow;

  /// Its marker's indent: as read where it fits, else none.
  int get _indent => switch (_source?.markerColumn) {
    final column? when column < indentBelow => column,
    _ => 0,
  };

  /// The column its content starts at.
  int get contentColumn => part(first: false).length;

  /// Spaces after its marker: as read, else one.
  int get _padding => switch (_source) {
    final source? =>
      (source.contentColumn -
              source.markerColumn -
              source.marker.toString().length)
          .clamp(1, 4),
    null => 1,
  };

  String get _box => switch (item.checked) {
    null => '',
    true => '[x] ',
    false => '[ ] ',
  };

  /// Whether its next line is its first, which holds its marker.
  bool pending = true;

  @override
  ItemBlock? get kept => switch (_source) {
    final source?
        when source.marker.toString() == marker &&
            source.checked == item.checked &&
            source.markerColumn == _indent =>
      source,
    _ => null,
  };

  @override
  String part({required bool first}) => first
      ? '${' ' * _indent}$marker${' ' * _padding}$_box'
      : ' ' * (_indent + marker.length + _padding);

  /// Whether its box must keep the space after it on an empty item's
  /// line.
  bool get hasBox => item.hasBox;
}
