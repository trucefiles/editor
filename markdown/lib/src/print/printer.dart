/// Prints a document tree as Markdown: blocks as read keep their lines,
/// the rest is written in the document's own style.
library;

import 'package:collection/collection.dart';

import '../doc/definitions.dart';
import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/origin.dart';
import '../document_tree.dart';
import '../lines/line_endings.dart';
import '../tree/blocks.dart';
import 'as_read.dart';
import 'frames.dart';
import 'leaf_lines.dart';
import 'print_style.dart';
import 'text_layouts.dart';
import 'writable.dart';

/// The lines a block printed to, first and last.
typedef LineRange = ({int first, int last});

/// A document printed: its [text], and the lines each leaf printed to.
typedef PrintedMarkdown = ({String text, Map<NodeId, LineRange> lines});

/// [doc] printed as Markdown, [origin] being where it was read from.
///
/// A block printed is a unit at any depth. A unit as read in the same
/// place, with the same marks before it, prints its lines byte for
/// byte; one as read under other marks keeps its lines with the marks
/// written anew; others are printed in their own style. Between units
/// that were read next to each other the blank lines read are kept;
/// elsewhere one blank line goes between blocks, none between the items
/// of a tight list, and none where nothing needs one in such an item.
PrintedMarkdown printMarkdown(DocTree doc, Origin origin) {
  final definitions = definitionsOf(doc.root);
  final layouts = TextLayouts(
    definitions: definitions,
    style: origin.markdown.style,
  );
  final writable = writableOf(doc, origin, layouts);
  return _Printer(
    origin,
    layouts,
    definitionsChanged: !const MapEquality<String, LinkDefinition>().equals(
      definitions,
      origin.markdown.definitions,
    ),
  ).print(writable.root);
}

/// What [doc] reads back as once printed (see `writableOf`): the seam
/// the round-trip tests compare by.
DocTree writableMarkdown(DocTree doc, Origin origin) => writableOf(
  doc,
  origin,
  TextLayouts(
    definitions: definitionsOf(doc.root),
    style: origin.markdown.style,
  ),
);

/// A printed line and the line ending after it; an empty ending is the
/// document's.
typedef _Line = ({String text, String ending});

final class _Printer {
  _Printer(this._origin, this._layouts, {required this.definitionsChanged});

  final Origin _origin;
  final TextLayouts _layouts;

  /// Whether the document's link definitions are other than as read.
  final bool definitionsChanged;

  final _out = <_Line>[];
  final _ranges = <NodeId, LineRange>{};
  final _frames = <Frame>[];
  final _path = <DocContainer>[];

  /// The column a block after each printed list must start before.
  final _indentsBelow = <NodeId, int>{};

  DocumentTree get _markdown => _origin.markdown;

  PrintedMarkdown print(DocRoot root) {
    final markdown = _origin.markdown;
    final lines = markdown.lines;
    if (_origin.isLoaded(root) && !definitionsChanged) {
      _copiedRanges(root, 0, 0);
      return (text: markdown.text, lines: _ranges);
    }
    final blocks = markdown.root.children;
    final leading = blocks.isEmpty
        ? 0
        : markdown.indexOf(lineSpanOf(blocks.first).first);
    final trailing = blocks.isEmpty
        ? lines.length
        : markdown.indexOf(lineSpanOf(blocks.last).last) + 1;
    // The text ends with a line ending: its last line is empty, and no
    // block took it in.
    final finalNewline =
        lines.length > 1 && lines.last.text.isEmpty && trailing < lines.length;
    final count = finalNewline ? lines.length - 1 : lines.length;
    // A new text ends with one too, as most tools expect.
    final endsWithNewline = finalNewline || markdown.text.isEmpty;
    if (_printable(root.children).isEmpty && blocks.isEmpty) {
      return (text: markdown.text, lines: _ranges);
    }
    if (_printable(root.children).isNotEmpty) {
      _copyLines(0, leading);
      _path.add(root);
      _children(root);
      _path.removeLast();
      _copyLines(trailing, count);
    }
    final text = StringBuffer(
      markdown.byteOrderMark ? byteOrderMarkCharacter : '',
    );
    for (final (index, line) in _out.indexed) {
      text.write(line.text);
      if (index < _out.length - 1 || endsWithNewline) {
        text.write(line.ending.isEmpty ? markdown.lineEnding : line.ending);
      }
    }
    return (text: text.toString(), lines: _ranges);
  }

  /// [children] without empty paragraphs, which print nothing (unless
  /// read so: a paragraph of an empty link).
  List<DocBlock> _printable(List<DocBlock> children) => [
    for (final child in children)
      if (child is! ParagraphNode || !writesNothing(child, _origin)) child,
  ];

  // Walking.

  void _children(DocContainer container) {
    final children = _printable(container.children);
    for (final (index, child) in children.indexed) {
      final previous = index == 0 ? null : children[index - 1];
      if (previous != null) _space(previous, child, container);
      _block(child, previous: previous, last: index == children.length - 1);
    }
  }

  void _block(DocBlock node, {DocBlock? previous, required bool last}) {
    switch (node) {
      case _ when _copyable(node, previous: previous, last: last):
        _copy(node);
      case QuoteNode():
        _within(node, QuoteFrame(node), () {
          if (_printable(node.children).isEmpty) _emit('');
          _children(node);
        });
      case ListNode():
        _path.add(node);
        // Out of the last item of a list right before it.
        var indentBelow = switch (previous) {
          ListNode(:final id) => _indentsBelow[id] ?? 4,
          _ => 4,
        };
        for (final (index, item) in node.items.indexed) {
          if (index > 0) _space(node.items[index - 1], item, node);
          indentBelow = _item(node, index, indentBelow: indentBelow);
        }
        _indentsBelow[node.id] = indentBelow;
        _path.removeLast();
      case ItemNode() || DocRoot():
        throw ArgumentError.value(node, 'node', 'not in a list');
      case final DocLeaf leaf when _keepsLines(leaf, previous, last: last):
        _reprefixed(leaf);
      case final DocLeaf leaf:
        _printed(leaf, previous);
    }
  }

  /// Prints item [index] of [list], its marker before column
  /// [indentBelow]; the column the next item's marker must start before.
  int _item(ListNode list, int index, {required int indentBelow}) {
    final item = list.items[index];
    final frame = ItemFrame(
      item,
      marker: _markerOf(list, index),
      indentBelow: indentBelow,
    );
    if (frame.kept != null && _copyable(item, previous: null, last: false)) {
      _copy(item);
    } else {
      _within(item, frame, () {
        final children = _printable(item.children);
        if (children.isEmpty || children.first is ListNode) {
          _emit('', keepTrailing: item.hasBox);
        }
        _children(item);
      });
    }
    return frame.contentColumn < 4 ? frame.contentColumn : 4;
  }

  void _within(DocContainer node, Frame frame, void Function() print) {
    _path.add(node);
    _frames.add(frame);
    print();
    _frames.removeLast();
    _path.removeLast();
  }

  String _markerOf(ListNode list, int index) => switch (list.kind) {
    ListKind.bullet => bulletOf(list, _markdown.style),
    ListKind.numbered => '${list.numberAt(index)}${delimiterOf(list)}',
  };

  // Spacing.

  void _space(DocBlock previous, DocBlock next, DocContainer container) {
    // Items of a list read apart without blank lines.
    final minimum = container is! ListNode && _needsBlank(previous, next)
        ? 1
        : 0;
    if (_readTogether(previous, next)) {
      final from = _markdown.indexOf(lineSpanOf(previous.source!).last) + 1;
      final to = _markdown.indexOf(lineSpanOf(next.source!).first);
      final asRead = _origin.isLoaded(previous) && _origin.isLoaded(next);
      if (asRead || to - from >= minimum) {
        if (_inPlace(previous.source!)) {
          _copyLines(from, to);
        } else {
          _blankLines(to - from);
        }
        return;
      }
    }
    final usual = switch (container) {
      ListNode() => _loose(container) ? 1 : 0,
      ItemNode() => _loose(_path[_path.length - 2] as ListNode) ? 1 : 0,
      _ => 1,
    };
    _blankLines(usual > minimum ? usual : minimum);
  }

  void _blankLines(int count) {
    for (var line = 0; line < count; line++) {
      _emit('');
    }
  }

  bool _loose(ListNode list) => switch (list.source) {
    ListBlock(:final loose) => loose,
    _ => false,
  };

  bool _readTogether(DocBlock previous, DocBlock next) =>
      kindKept(previous) &&
      kindKept(next) &&
      _origin.areNeighbors(previous.source!, next.source!);

  /// Whether a blank line must go between [previous] and [next] so that
  /// they read apart: after raw blocks, between quotes, after a block that
  /// ends in a paragraph (unless [next] interrupts one), and before
  /// indented code.
  bool _needsBlank(DocBlock previous, DocBlock next) => switch (previous) {
    _ when next is CodeNode && _indented(next, previous) => true,
    RawLeaf() => true,
    QuoteNode() when next is QuoteNode => true,
    _ => _endsInParagraph(previous) && !_interrupts(next),
  };

  bool _endsInParagraph(DocBlock node) => switch (node) {
    ParagraphNode() => true,
    DocContainer(:final children) => switch (_printable(children).lastOrNull) {
      final last? => _endsInParagraph(last),
      null => false,
    },
    _ => false,
  };

  /// Whether [node] starts a block that ends a paragraph before it.
  bool _interrupts(DocBlock node) => switch (node) {
    final HeadingNode heading => !isSetext(heading),
    final CodeNode code => !_indented(code, null),
    QuoteNode() => true,
    ListNode(:final items, :final kind) =>
      (kind == ListKind.bullet || node.numberAt(0) == 1) &&
          switch (_printable(items.first.children).firstOrNull) {
            null || ListNode() => false,
            _ => true,
          },
    _ => false,
  };

  // Units as read.

  /// Whether [node] prints its lines as read: it is as read, in the same
  /// place under the same marks, and nothing around it needs it printed.
  bool _copyable(DocBlock node, {DocBlock? previous, required bool last}) {
    final source = node.source;
    return _origin.isLoaded(node) &&
        source != null &&
        !_forced(node, previous, last: last) &&
        !(definitionsChanged &&
            hasStaleReference(node, _layouts.definitions)) &&
        _inPlace(source) &&
        _frames.whereType<ItemFrame>().every(
          (frame) =>
              frame.pending ==
              (frame.kept!.markerLine == lineSpanOf(source).first),
        );
  }

  /// Whether lines read in [source] are in the same containers as read,
  /// each with its marks as read.
  bool _inPlace(Block source) {
    final path = _origin.placeOf(source)?.path;
    return path != null &&
        path.length == _path.length &&
        Iterable<int>.generate(path.length)
            .every((index) => identical(path[index], _path[index].source)) &&
        _frames.every((frame) => frame.kept != null);
  }

  /// Whether [leaf], as read, keeps its lines under new marks: none of
  /// them is indented with a tab, and its first line holds an item's
  /// marker now as it did.
  bool _keepsLines(DocLeaf leaf, DocBlock? previous, {required bool last}) {
    final source = leaf.source;
    if (!_origin.isLoaded(leaf) ||
        source is! LeafBlock ||
        _forced(leaf, previous, last: last) ||
        (definitionsChanged && hasStaleReference(leaf, _layouts.definitions))) {
      return false;
    }
    return linesTakeNewMarks(
      source,
      _markdown,
      startsItem: _frames.any((frame) => frame is ItemFrame && frame.pending),
    );
  }

  /// Whether [node], as read, must be printed anew where it is now:
  /// code or an indented block that would join the block before it, open
  /// fenced
  /// code before other blocks (it would take them in).
  bool _forced(DocBlock node, DocBlock? previous, {required bool last}) =>
      switch (node.source) {
        CodeBlock(fenced: true, closed: false) => !last,
        final source? =>
          joinsIndented(previous) &&
              (source is CodeBlock || indentedAsRead(source, _origin)) &&
              !_readAfter(previous!, node),
        null => false,
      };

  /// Whether [node] is read right after [previous], both as read.
  bool _readAfter(DocBlock previous, DocBlock node) =>
      _origin.isLoaded(previous) && _readTogether(previous, node);

  void _copy(DocBlock node) {
    final span = lineSpanOf(node.source!);
    final from = _markdown.indexOf(span.first);
    final to = _markdown.indexOf(span.last) + 1;
    _copiedRanges(node, _out.length, from);
    _copyLines(from, to);
    for (final frame in _frames.whereType<ItemFrame>()) {
      frame.pending = false;
    }
  }

  void _copyLines(int from, int to) {
    for (final line in _origin.markdown.lines.sublist(from, to)) {
      _out.add((text: line.text, ending: line.ending));
    }
  }

  /// Notes the lines of [node]'s leaves, copied to [start] from source
  /// line [from] on.
  void _copiedRanges(DocBlock node, int start, int from) {
    for (final leaf in leavesIn(node)) {
      if (leaf.source case final LeafBlock source) {
        _ranges[leaf.id] = (
          first: start + _markdown.indexOf(source.lines.first.id) - from,
          last: start + _markdown.indexOf(source.lines.last.id) - from,
        );
      }
    }
  }

  void _reprefixed(DocLeaf leaf) {
    final source = leaf.source! as LeafBlock;
    final start = _out.length;
    for (final line in source.lines) {
      _emit(
        line.text.substring(line.prefix.isEmpty ? 0 : line.prefix.last.end),
        from: line,
        ending: _markdown.lines[_markdown.indexOf(line.id)].ending,
      );
    }
    _ranges[leaf.id] = (first: start, last: _out.length - 1);
  }

  // Units printed anew.

  void _printed(DocLeaf leaf, DocBlock? previous) {
    final start = _out.length;
    // Its lines end as its source's mostly do; else as the document's.
    final endings = switch (leaf.source) {
      final LeafBlock source => [
        for (final line in source.lines)
          if (_markdown.lines[_markdown.indexOf(line.id)].ending
              case final ending when ending.isNotEmpty)
            ending,
      ],
      _ => const <String>[],
    };
    final ending = endings.isEmpty ? '' : dominantEnding(endings);
    void emit(String content) => _emit(content, ending: ending);
    switch (leaf) {
      case ParagraphNode():
        _textLines(leaf).forEach(emit);
      case HeadingNode() when isSetext(leaf):
        _textLines(leaf).forEach(emit);
        emit(underlineOf(leaf));
      case HeadingNode():
        emit(atxHeading(leaf, _layouts));
      case CodeNode():
        codeLines(leaf, indented: _indented(leaf, previous)).forEach(emit);
      case DividerNode():
        emit(_divider());
      case RawLeaf(:final raw):
        raw.split('\n').forEach(emit);
    }
    _ranges[leaf.id] = (first: start, last: _out.length - 1);
  }

  /// Whether [code] prints indented after [previous] here.
  bool _indented(CodeNode code, DocBlock? previous) => printsIndented(
    code,
    previous,
    firstInItem: previous == null && _path.last is ItemNode,
  );

  /// [node]'s text in lines after the containers' marks.
  List<String> _textLines(TextNode node) => textLines(
    node,
    _layouts,
    firstPrefix: _prefixWidth(first: true),
    restPrefix: _prefixWidth(first: false),
  );

  int _prefixWidth({required bool first}) => _frames
      .map(
        (frame) => frame
            .part(first: first && frame is ItemFrame && frame.pending)
            .length,
      )
      .sum;

  /// A divider that doesn't read as an item's marker before it.
  String _divider() =>
      _frames.any(
        (frame) => frame is ItemFrame && frame.pending && frame.marker == '-',
      )
      ? '***'
      : '---';

  // Lines.

  /// Adds a line of [content] after the containers' marks: those as read
  /// on [from] where kept, else written anew. A line with no content
  /// ends at its marks, without trailing spaces unless [keepTrailing].
  void _emit(
    String content, {
    SourceLine? from,
    String ending = '',
    bool keepTrailing = false,
  }) {
    final firsts = [
      for (final frame in _frames) frame is ItemFrame && frame.pending,
    ];
    final parts = [
      for (final (index, frame) in _frames.indexed)
        (from == null ? null : frame.keptPart(from, first: firsts[index])) ??
            frame.part(first: firsts[index]),
    ];
    for (final frame in _frames.whereType<ItemFrame>()) {
      frame.pending = false;
    }
    final text = '${parts.join()}$content';
    _out.add((
      text: content.isEmpty && !keepTrailing ? text.trimRight() : text,
      ending: ending,
    ));
  }
}
