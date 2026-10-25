import 'package:collection/collection.dart';

import '../../document_tree.dart';
import '../../lines/line.dart';
import '../../lines/line_change.dart';
import '../../read/block_freezer.dart';
import '../../tree/blocks.dart';
import '../../visible/visible_text.dart';
import '../draft.dart';
import 'frames.dart';
import 'gaps.dart';
import 'leaf_lines.dart';

/// The lines a draft writes, and the ids its blocks take, by kind and
/// first line (index among the lines), outermost first.
typedef WrittenLines = ({
  List<NewLine> lines,
  Map<(BlockKind, int), List<BlockId>> planned,
});

/// The lines that write [draft] over [tree]: blocks kept where they were
/// keep their lines' bytes; others are written in their containers'
/// style, with blank lines where the blocks need them. Old lines keep
/// their ids where the draft keeps or rewrites them, each once.
WrittenLines writeLines(DocumentTree tree, RootDraft draft) =>
    _BlockWriter(tree).write(draft);

/// One line written: its containers' parts and its own part, or the old
/// line's text where it is written as it was.
final class _Line {
  _Line(this.id, this.parts, this.own, {this.verbatim});

  final LineId? id;
  final List<String> parts;
  final String own;
  final String? verbatim;

  String get text => verbatim ?? '${parts.join()}$own';

  /// What it says after the parts of the first [depth] containers.
  String textFrom(int depth) => '${parts.skip(depth).join()}$own';
}

final class _BlockWriter {
  _BlockWriter(this.tree);

  final DocumentTree tree;
  final _lines = <_Line>[];
  final _planned = <(BlockKind, int), List<BlockId>>{};
  final _used = <LineId>{};
  final _frames = <Frame>[];

  /// How far each list's last item indents its lines after the first.
  final _lastItemIndents = <BlockId, int>{};

  /// The kind and marker family each list was written with.
  final _families = <BlockId, (ListKind, String)>{};

  WrittenLines write(RootDraft draft) {
    final root = draft.root;
    if (root.children.isEmpty && draft.children.isNotEmpty) {
      // A document without blocks gets its first one at its first line; its
      // other lines (a final line break) stay after it.
      _children(draft.children, old: root, spacing: Spacing.blocks);
      for (final line in tree.lines.skip(1)) {
        _layoutLine(line, root);
      }
    } else {
      _edgeLines(root, leading: true);
      _children(draft.children, old: root, spacing: Spacing.blocks);
      _edgeLines(root, leading: false);
    }
    if (_lines.isEmpty) {
      _lines.add(_Line(_reuse(tree.lines.first.id), const [], ''));
    }
    return (
      lines: [for (final line in _lines) (id: line.id, text: line.text)],
      planned: _planned,
    );
  }

  /// [id] if no written line has it yet, which it now has.
  LineId? _reuse(LineId? id) => id != null && _used.add(id) ? id : null;

  void _plan(BlockKind kind, BlockId id) =>
      (_planned[(kind, _lines.length)] ??= []).add(id);

  int get _depth => _frames.length;

  /// Whether [old], a block of the old tree, sits in the same containers
  /// now.
  bool _samePath(Block old) => const ListEquality<BlockId>().equals(
    <BlockId>[
      for (final container
          in tree.placeOf(old.id)?.path ?? const <ContainerBlock>[])
        if (container is QuoteBlock || container is ItemBlock) container.id,
      if (old is QuoteBlock || old is ItemBlock) old.id,
    ],
    [for (final frame in _frames) frame.id],
  );

  /// Whether all of [olds] sit in the same containers now, which keep
  /// their columns.
  bool _samePlace(List<Block> olds) =>
      olds.isNotEmpty &&
      olds.every(_samePath) &&
      _frames.every((frame) => frame is! ItemFrame || frame.keepsIndent);

  /// Whether lines of [old] from [line] on are written as they were: in
  /// the same containers, none restyled, a marker still to come only on
  /// its old line, and none on a line that held one already written.
  bool _inPlace(Block old, LineId line) =>
      _samePath(old) &&
      _frames.every(
        (frame) =>
            frame is! ItemFrame ||
            (frame.keepsIndent &&
                (frame.markerPending
                    ? frame.keepsMarker && frame.oldMarkerLine == line
                    : frame.oldMarkerLine != line)),
      );

  /// The containers' parts of a line, rewriting [old] if given (see
  /// [Frame.partOf]), before [own]; a blank line's end trimmed, unless it
  /// ends in a marker just opened, which is written as an empty item's.
  List<String> _parts(
    SourceLine? old, {
    String own = '',
    required bool blank,
    required bool lazy,
  }) {
    final opens = [
      for (final frame in _frames) frame is ItemFrame && frame.markerPending,
    ];
    final parts = <String>[];
    // A tab spans as many columns only behind the same bytes: behind a
    // part that is not the old one, the old parts are written anew from
    // the first whose bytes up to the leaf's part hold a tab.
    var moved = false;
    var anew = false;
    for (final frame in _frames) {
      final oldPart = frame.oldPartOf(old);
      // Only the innermost part ends a blank line; others have marks after.
      final ends = blank && frame == _frames.last;
      anew =
          anew ||
          (moved && (oldPartsFrom(old, frame.id)?.contains('\t') ?? false));
      final part = anew
          ? frame.partOf(null, blank: ends, lazy: false)
          : frame.partOf(old, blank: ends, lazy: lazy);
      parts.add(part);
      moved = moved || part != oldPart;
    }
    final last = parts.lastIndexWhere((part) => part.trim().isNotEmpty);
    return _quotesSpaced(
      !blank || (last >= 0 && opens[last]) ? parts : _trimmedEnd(parts),
      own,
    );
  }

  /// [parts], and [own] after them, with a space after each quote's `>`
  /// that is right before a space, which the quote would take as its own.
  /// (A tab after it is old bytes, which the quote took part of before.)
  List<String> _quotesSpaced(List<String> parts, String own) => [
    for (final (index, part) in parts.indexed)
      _frames[index] is QuoteFrame &&
              part.endsWith('>') &&
              '${parts.skip(index + 1).join()}$own'.startsWith(' ')
          ? '$part '
          : part,
  ];

  /// Writes a leaf's line with [own] as its own part, rewriting [old] if
  /// given, with its containers' parts as on [old] unless [newParts].
  void _leafLine(SourceLine? old, String own, {required bool newParts}) =>
      _lines.add(
        _Line(
          _reuse(old?.id),
          _parts(
            newParts ? null : old,
            own: own,
            blank: own.isEmpty,
            lazy:
                old != null &&
                isLazy(old, tree.leafOf(old.id)!) &&
                _samePlace([tree.leafOf(old.id)!]),
          ),
          own,
        ),
      );

  /// Writes the layout line [old] (blank, or only marks) of [container]:
  /// as it was if its containers are, else anew.
  void _layoutLine(Line old, Block container) {
    final verbatim = _inPlace(container, old.id) ? old.text : null;
    _lines.add(
      _Line(
        _reuse(old.id),
        _parts(null, blank: true, lazy: false),
        '',
        verbatim: verbatim,
      ),
    );
  }

  void _blankLine({LineId? id}) =>
      _lines.add(_Line(id, _parts(null, blank: true, lazy: false), ''));

  /// Writes the old lines of [container] before its first block
  /// ([leading]) or after its last, which hold no block.
  void _edgeLines(ContainerBlock container, {required bool leading}) {
    for (final index in _edgeIndexes(container, leading: leading)) {
      _layoutLine(tree.lines[index], container);
    }
  }

  Iterable<int> _edgeIndexes(
    ContainerBlock container, {
    required bool leading,
  }) {
    final (first, last) = switch (container) {
      RootBlock() => (0, tree.lines.length - 1),
      _ => (
        tree.indexOf(lineSpanOf(container).first),
        tree.indexOf(lineSpanOf(container).last),
      ),
    };
    final children = container.children;
    if (children.isEmpty) return leading ? _range(first, last + 1) : const [];
    return leading
        ? _range(first, tree.indexOf(lineSpanOf(children.first).first))
        : _range(tree.indexOf(lineSpanOf(children.last).last) + 1, last + 1);
  }

  /// Writes [children] of a container that was [old], if it was one,
  /// with the blank lines [spacing] says between them.
  void _children(
    List<Draft> children, {
    required ContainerBlock? old,
    required Spacing spacing,
  }) => _spaced(
    children,
    old: old,
    spacing: spacing,
    write: (child, index) => _draft(
      child,
      after: index > 0 ? children[index - 1] : null,
      last: index == children.length - 1,
    ),
  );

  /// Writes [drafts] with [write], and the blank lines [spacing] says
  /// between those that write lines.
  void _spaced<T extends Draft>(
    List<T> drafts, {
    required ContainerBlock? old,
    required Spacing spacing,
    required void Function(T draft, int index) write,
  }) {
    T? before;
    for (final (index, draft) in drafts.indexed) {
      final start = _lines.length;
      write(draft, index);
      if (_lines.length == start) continue;
      if (before != null) {
        final written = _lines.sublist(start);
        _lines.removeRange(start, _lines.length);
        _gap(before, draft, written, old: old, spacing: spacing);
        _shiftPlanned(from: start, by: _lines.length - start);
        _lines.addAll(written);
      }
      before = draft;
    }
  }

  /// Moves the planned ids of lines from [from] on [by] lines down.
  void _shiftPlanned({required int from, required int by}) {
    if (by == 0) return;
    final moved = [
      for (final entry in _planned.entries)
        if (entry.key.$2 >= from) entry,
    ];
    _planned
      ..removeWhere((key, _) => key.$2 >= from)
      ..addEntries([
        for (final MapEntry(key: (kind, line), :value) in moved)
          MapEntry((kind, line + by), value),
      ]);
  }

  /// Writes the blank lines between [before] and [next], whose first line
  /// reads [nextLine] after the containers' marks: the old ones where
  /// they were neighbors, one where the blocks need it or the list is
  /// loose, else as many as the old document had there.
  void _gap(
    Draft before,
    Draft next,
    List<_Line> nextLines, {
    required ContainerBlock? old,
    required Spacing spacing,
  }) {
    final kept = _oldGap(before, next, old);
    final blank = blankNeeded(
      before,
      nextLines.first.textFrom(_depth),
      spacing: spacing,
    );
    // Where the old lines between them stay, so may their reading.
    final needed =
        blank && !(kept != null && _sameEdges(before, next, nextLines));
    final count = switch (spacing) {
      Spacing.tightItems => 0,
      Spacing.tightInItem => blank ? 1 : 0,
      _ when kept != null && (kept.isNotEmpty || !needed) => kept.length,
      Spacing.looseItems => 1,
      Spacing.blocks ||
      Spacing.looseInItem => needed ? 1 : _knownGap(before, next),
    };
    for (final index in _range(0, count)) {
      switch (kept?.elementAtOrNull(index)) {
        case final line?:
          _layoutLine(line, old!);
        case null:
          _blankLine();
      }
    }
  }

  /// Whether the lines where [before] ends and [next] (written as
  /// [nextLines]) starts say what they said, in the old leaves that ended
  /// and started their old blocks: then they still read as they did next
  /// to each other.
  bool _sameEdges(Draft before, Draft next, List<_Line> nextLines) {
    final end = _lastOldLeaf(before);
    final start = _firstOldLeaf(next);
    bool same(SourceLine old, Iterable<_Line> lines) => lines.any(
      (line) =>
          line.id == old.id && line.own == old.text.substring(prefixEndOf(old)),
    );
    return end != null &&
        start != null &&
        end.id == oldEndOf(before)?.leaves.lastOrNull?.id &&
        start.id == oldStartOf(next)?.leaves.firstOrNull?.id &&
        same(end.lines.last, _lines.reversed) &&
        same(start.lines.first, nextLines);
  }

  /// The old lines between [before] and [next], if they were neighbors
  /// in [old].
  List<Line>? _oldGap(Draft before, Draft next, ContainerBlock? old) {
    final (end, start) = (oldEndOf(before), oldStartOf(next));
    if (old == null || end == null || start == null) return null;
    final index = old.children.indexWhere((child) => child.id == end.id);
    if (index < 0 || old.children.elementAtOrNull(index + 1)?.id != start.id) {
      return null;
    }
    return tree.lines.sublist(
      tree.indexOf(lineSpanOf(end).last) + 1,
      tree.indexOf(lineSpanOf(start).first),
    );
  }

  /// How many blank lines the old document had after [before]'s old block or
  /// before [next]'s, where neither needs one.
  int _knownGap(Draft before, Draft next) =>
      [
        if (oldEndOf(before) case final end?) _oldGapAround(end, after: true),
        if (oldStartOf(next) case final start?)
          _oldGapAround(start, after: false),
      ].nonNulls.firstOrNull ??
      0;

  /// How many lines were between [block] and its neighbor after it
  /// ([after]) or before it; `null` if it had none.
  int? _oldGapAround(Block block, {required bool after}) {
    final siblings = tree.parentOf(block)?.children ?? const <Block>[];
    final index = siblings.indexWhere((child) => child.id == block.id);
    if (index < 0) return null;
    final (first, second) = after
        ? (block, siblings.elementAtOrNull(index + 1))
        : (index > 0 ? siblings[index - 1] : null, block);
    if (first == null || second == null) return null;
    return tree.indexOf(lineSpanOf(second).first) -
        tree.indexOf(lineSpanOf(first).last) -
        1;
  }

  /// Writes [draft], right [after] a block of its container or first,
  /// the [last] block of its container or not.
  void _draft(Draft draft, {required Draft? after, required bool last}) =>
      switch (draft) {
        KeptDraft(block: final CodeBlock code) when _joins(code, after) =>
          _draft(CodeDraft(code, code.code), after: after, last: last),
        KeptDraft(block: final TextLeaf leaf)
            when _goesOnInList(leaf, after) ||
                !_inPlace(leaf, leaf.lines.first.id) =>
          _draft(_restated(leaf), after: after, last: last),
        KeptDraft(block: final LeafBlock leaf) => _keptLeaf(leaf, last: last),
        KeptDraft(:final block) => _draft(
          asDraft(block),
          after: after,
          last: last,
        ),
        TextDraft(:final from) => _ownLines(
          draft.id,
          draft.level == null ? BlockKind.paragraph : BlockKind.heading,
          textLines(
            draft,
            tree,
            inPlace: _samePlace(from),
            indentFirst: !from.any((leaf) => _goesOnInList(leaf, after)),
          ),
        ),
        CodeDraft(:final from) => _ownLines(
          draft.id,
          BlockKind.code,
          _joins(from, after) || !from.fenced && !indentedCanHold(draft.code)
              ? fencedCodeLines(from, draft.code)
              : codeLines(draft, inPlace: _samePath(from), closed: !last),
        ),
        QuoteDraft() => _quote(draft),
        ListDraft() => _list(draft, after: after),
        ItemDraft() => throw ArgumentError.value(
          draft,
          'draft',
          'an item outside a list',
        ),
      };

  /// Whether [leaf]'s first line, written with its own indent right
  /// [after] a list, would go on in the list's last item.
  bool _goesOnInList(LeafBlock leaf, Draft? after) =>
      switch (_lastItemIndents[after?.id]) {
        final width? => _ownIndentOf(leaf.lines.first) >= width,
        null => false,
      };

  /// Whether [code], written indented right [after] a block, would join
  /// it: an indented code block, or a list whose last item it would go
  /// on in.
  bool _joins(CodeBlock code, Draft? after) =>
      !code.fenced && (_isIndentedCode(after) || _goesOnInList(code, after));

  void _keptLeaf(LeafBlock leaf, {required bool last}) {
    final opensOn = switch (leaf) {
      CodeBlock(fenced: true, closed: false) => !last,
      _ => false,
    };
    if (opensOn || !_inPlace(leaf, leaf.lines.first.id)) {
      _ownLines(leaf.id, BlockKind.of(leaf), switch (leaf) {
        CodeBlock(:final code) => codeLines(
          CodeDraft(leaf, code),
          inPlace: _samePath(leaf),
          closed: !last,
        ),
        _ => keptLines(leaf),
      });
      return;
    }
    _plan(BlockKind.of(leaf), leaf.id);
    for (final line in leaf.lines) {
      _lines.add(
        _Line(
          _reuse(line.id),
          _parts(line, blank: false, lazy: true),
          line.text.substring(prefixEndOf(line)),
          verbatim: line.text,
        ),
      );
    }
  }

  void _ownLines(BlockId id, BlockKind kind, List<OwnLine> lines) {
    _plan(kind, id);
    for (final (:old, :own, :newParts) in lines) {
      _leafLine(old, own, newParts: newParts);
    }
  }

  void _quote(QuoteDraft draft) {
    final old = draft.from;
    _plan(BlockKind.quote, draft.id);
    _frames.add(QuoteFrame(draft.id, mark: _quoteMark(old)));
    final start = _lines.length;
    if (old != null) _edgeLines(old, leading: true);
    _children(draft.children, old: old, spacing: Spacing.blocks);
    if (old != null) _edgeLines(old, leading: false);
    if (_lines.length == start) _blankLine(id: _reuse(old?.firstLine));
    _frames.removeLast();
  }

  /// The mark a quote's new lines take: `>` where its first text line
  /// has no space after its mark, else `> `.
  String _quoteMark(QuoteBlock? quote) {
    final line = quote?.leaves.firstOrNull?.lines.first;
    final part = line?.prefix.firstWhereOrNull(
      (part) => part.container == quote?.id,
    );
    return switch ((line, part)) {
      (final line?, final part?)
          when line.text.substring(part.start, part.end).endsWith('>') &&
              !_startsWithSpace.hasMatch(line.text.substring(part.end)) =>
        '>',
      _ => '> ',
    };
  }

  void _list(ListDraft draft, {required Draft? after}) {
    _plan(BlockKind.list, draft.id);
    final items = [
      for (final item in draft.items)
        switch (item) {
          final ItemDraft item => item,
          KeptDraft(block: final ItemBlock block) => ItemDraft.of(block, [
            for (final child in block.children) KeptDraft(child),
          ]),
          _ => throw ArgumentError.value(item, 'item', 'no item'),
        },
    ];
    final usual = _markerFamily(draft, items);
    // A list right after one of its kind and family would read as part of
    // it: it takes the other family.
    final family = switch (_families[after?.id]) {
      (final kind, final family) when kind == draft.kind && family == usual =>
        _otherFamily(usual),
      _ => usual,
    };
    _families[draft.id] = (draft.kind, family);
    MarkerStyle? above;
    _spaced(
      items,
      old: draft.from,
      spacing: draft.loose ? Spacing.looseItems : Spacing.tightItems,
      write: (item, index) {
        above = _item(item, draft, family, index, above: above);
      },
    );
    // An empty last item ends at the next line; others go on in lines
    // indented as far as their content.
    if (items.last.children.isNotEmpty) {
      _lastItemIndents[draft.id] = above!.continuation.length;
    }
  }

  /// The bullet character or number delimiter of [draft]'s markers: its
  /// first old item's of its kind, else the document's.
  String _markerFamily(ListDraft draft, List<ItemDraft> items) {
    final marker = [
      ...items.map((item) => item.from?.marker),
      ...?draft.from?.items.map((item) => item.marker),
    ].nonNulls.where((marker) => marker.kind == draft.kind).firstOrNull;
    return switch (draft.kind) {
      ListKind.bullet => marker?.bullet ?? tree.style.bullet,
      ListKind.numbered => marker?.delimiter ?? '.',
    };
  }

  /// Writes [draft], item [index] of [list], below an item written in
  /// the style [above] if any; returns its own style.
  MarkerStyle _item(
    ItemDraft draft,
    ListDraft list,
    String family,
    int index, {
    required MarkerStyle? above,
  }) {
    final old = draft.from;
    final marker = switch (list.kind) {
      ListKind.bullet => family,
      ListKind.numbered =>
        '${switch (list.numbering) {
          Numbering.sequential => list.start + index,
          Numbering.same => list.start,
        }}$family',
    };
    final template = old != null
        ? MarkerStyle.of(old)
        : above ?? _neighborStyle(list) ?? MarkerStyle(marker: marker);
    // A marker as far in as the content above would go on in that item;
    // indented code first in an item starts one space after its marker.
    final style = template.withMarker(
      marker,
      checked: draft.checked,
      indent: switch (above?.continuation.length) {
        final reach? when template.indent.length >= reach => ' ' * (reach - 1),
        _ => template.indent,
      },
      padding: _startsWithIndentedCode(draft) ? ' ' : template.padding,
    );
    final keepsIndent =
        old != null && style.continuation.length == old.contentColumn;
    final frame = ItemFrame(
      draft.id,
      marker: style.part(empty: false),
      emptyMarker: style.part(empty: true),
      indent: style.continuation,
      oldMarkerLine: old?.markerLine,
      keepsMarker:
          keepsIndent &&
          old.marker.toString() == marker &&
          old.checked == draft.checked,
      keepsIndent: keepsIndent,
    );
    _plan(BlockKind.item, draft.id);
    _frames.add(frame);
    final startsAsBefore = switch ((
      draft.children.firstOrNull,
      old?.children.firstOrNull,
    )) {
      (final first?, final oldFirst?) => oldStartOf(first)?.id == oldFirst.id,
      (null, _) => true,
      (_, null) => false,
    };
    if (old != null && startsAsBefore) {
      _edgeLines(old, leading: true);
    }
    if (draft.children.isEmpty && frame.markerPending) {
      _blankLine(id: _reuse(old?.markerLine));
    }
    _children(
      draft.children,
      old: old,
      spacing: list.loose ? Spacing.looseInItem : Spacing.tightInItem,
    );
    _frames.removeLast();
    return style;
  }

  /// The marker style of a new first item in [list]: its old first
  /// item's.
  MarkerStyle? _neighborStyle(ListDraft list) =>
      switch (list.from?.items.firstOrNull) {
        final item? => MarkerStyle.of(item),
        null => null,
      };
}

/// [leaf] as a draft that says its text anew.
TextDraft _restated(TextLeaf leaf) => TextDraft(
  leaf.id,
  visibleTextOf(leaf.text),
  level: leaf is HeadingBlock ? leaf.level : null,
  from: [leaf],
);

/// Whether [item] starts with an indented code block.
bool _startsWithIndentedCode(ItemDraft item) =>
    switch (item.children.firstOrNull) {
      CodeDraft(from: CodeBlock(fenced: false)) ||
      KeptDraft(block: CodeBlock(fenced: false)) => true,
      _ => false,
    };

/// The old leaf [draft] ends with, if it ends with one.
LeafBlock? _lastOldLeaf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block.leaves.lastOrNull,
  TextDraft(:final from) => from.lastOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final items) => _lastOldLeaf(items.last),
  ItemDraft(:final children) || QuoteDraft(:final children) =>
    children.isEmpty ? null : _lastOldLeaf(children.last),
};

/// The old leaf [draft] starts with, if it starts with one.
LeafBlock? _firstOldLeaf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block.leaves.firstOrNull,
  TextDraft(:final from) => from.firstOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final items) => _firstOldLeaf(items.first),
  ItemDraft(:final children) || QuoteDraft(:final children) =>
    children.isEmpty ? null : _firstOldLeaf(children.first),
};

/// Whether [draft] is an indented code block, which another right after
/// it would join.
bool _isIndentedCode(Draft? draft) => switch (draft) {
  CodeDraft(from: CodeBlock(fenced: false)) ||
  KeptDraft(block: CodeBlock(fenced: false)) => true,
  _ => false,
};

/// How many columns [line]'s own part is indented, a tab counted as four.
int _ownIndentOf(SourceLine line) {
  final own = line.text.substring(prefixEndOf(line));
  return own
      .substring(0, own.length - own.trimLeft().length)
      .replaceAll('\t', '    ')
      .length;
}

/// The marker family that starts another list next to one of [family].
String _otherFamily(String family) => switch (family) {
  '-' => '*',
  '*' || '+' => '-',
  '.' => ')',
  _ => '.',
};

final _startsWithSpace = RegExp(r'^[ \t]');

Iterable<int> _range(int from, int to) =>
    Iterable.generate(to - from, (index) => from + index);

/// [parts] with the whitespace at their joint end taken off.
List<String> _trimmedEnd(List<String> parts) {
  final last = parts.lastIndexWhere((part) => part.trim().isNotEmpty);
  return [
    for (final (index, part) in parts.indexed)
      index < last ? part : (index == last ? part.trimRight() : ''),
  ];
}

/// [block] as a draft that keeps it and all in it.
Draft asDraft(Block block) => switch (block) {
  QuoteBlock() => QuoteDraft.of(block, [
    for (final child in block.children) KeptDraft(child),
  ]),
  ListBlock() => ListDraft.of(block, [
    for (final item in block.items) KeptDraft(item),
  ]),
  ItemBlock() => ItemDraft.of(block, [
    for (final child in block.children) KeptDraft(child),
  ]),
  RootBlock() || LeafBlock() => KeptDraft(block),
};

/// The old block whose end [draft]'s end is.
Block? oldEndOf(Draft draft) => switch (draft) {
  KeptDraft(:final block) => block,
  TextDraft(:final from) => from.lastOrNull,
  CodeDraft(:final from) => from,
  ListDraft(:final from) => from,
  ItemDraft(:final from) => from,
  QuoteDraft(:final from) => from,
};

/// The old block whose start [draft]'s start is.
Block? oldStartOf(Draft draft) => switch (draft) {
  TextDraft(:final from) => from.firstOrNull,
  _ => oldEndOf(draft),
};
