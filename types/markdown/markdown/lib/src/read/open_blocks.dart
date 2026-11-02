/// Blocks while the block reader reads them: open until finalized, and
/// mutable only inside the reader.
library;

import 'package:collection/collection.dart';

import '../tree/blocks.dart';

/// A block being read.
sealed class OpenBlock {
  OpenBlock(this.firstLine);

  OpenContainer? parent;
  bool open = true;

  /// The index of its first line.
  final int firstLine;

  /// The index of the last line it took, once finalized.
  late int lastLine;
}

/// A container's part of one line, while reading.
typedef Segment = ({OpenContainer container, int start, int end, int columns});

/// A leaf's line, while reading.
final class ReadLine {
  ReadLine(
    this.index, {
    required this.contentStart,
    required this.prefix,
    this.tabColumns = 0,
  });

  final int index;
  final int contentStart;
  final List<Segment> prefix;
  final int tabColumns;
}

/// A container while reading.
sealed class OpenContainer extends OpenBlock {
  OpenContainer(super.firstLine);

  final children = <OpenBlock>[];

  bool canContain(OpenBlock child) => child is! OpenItem;

  /// Its last child, if that is still open.
  OpenBlock? get lastOpenChild => switch (children.lastOrNull) {
    final OpenBlock child when child.open => child,
    _ => null,
  };

  /// Whether it holds no block yet.
  bool get isEmpty => children.isEmpty;
}

final class OpenRoot extends OpenContainer {
  OpenRoot() : super(0);
}

final class OpenQuote extends OpenContainer {
  OpenQuote(super.firstLine);
}

final class OpenList extends OpenContainer {
  OpenList(super.firstLine, this.marker);

  /// The marker of its first item, which later items must continue.
  final ItemMarker marker;

  @override
  bool canContain(OpenBlock child) => child is OpenItem;
}

final class OpenItem extends OpenContainer {
  OpenItem(
    super.firstLine, {
    required this.marker,
    required this.markerOffset,
    required this.padding,
    required this.checked,
  });

  final ItemMarker marker;
  final int markerOffset;
  final int padding;
  final bool? checked;

  int get contentColumn => markerOffset + padding;
}

/// A leaf while reading.
sealed class OpenLeaf extends OpenBlock {
  OpenLeaf(super.firstLine);

  final lines = <ReadLine>[];

  /// Whether it takes the lines that reach it, unlike a paragraph, which
  /// new blocks may interrupt.
  bool get takesLines => false;
}

final class OpenParagraph extends OpenLeaf {
  OpenParagraph(super.firstLine);

  /// Link reference definitions at its start, read once it ends, and how
  /// many of its lines they take.
  List<LinkDefinition> definitions = const [];
  int definitionLines = 0;
  bool definitionsRead = false;
}

final class OpenHeading extends OpenLeaf {
  OpenHeading(super.firstLine, {required this.level, required this.style});

  final int level;
  final HeadingStyle style;
}

final class OpenCode extends OpenLeaf {
  OpenCode.fenced(
    super.firstLine, {
    required String this.fence,
    required this.fenceOffset,
    required this.fenceStart,
  });

  OpenCode.indented(super.firstLine)
    : fence = null,
      fenceOffset = 0,
      fenceStart = 0;

  /// The opening fence; `null` if indented.
  final String? fence;

  /// How far the opening fence is indented: lines inside lose as much.
  final int fenceOffset;

  /// Where the opening fence starts on its line.
  final int fenceStart;
  bool closed = false;

  bool get fenced => fence != null;

  @override
  bool get takesLines => true;
}

final class OpenHtml extends OpenLeaf {
  OpenHtml(super.firstLine, this.kind);

  /// Its start condition, 1 to 7.
  final int kind;

  @override
  bool get takesLines => true;
}

final class OpenTable extends OpenLeaf {
  OpenTable(super.firstLine, this.alignments);

  final List<CellAlignment> alignments;
}

final class OpenRule extends OpenLeaf {
  OpenRule(super.firstLine);
}

final class OpenFrontMatter extends OpenLeaf {
  OpenFrontMatter() : super(0);
}
