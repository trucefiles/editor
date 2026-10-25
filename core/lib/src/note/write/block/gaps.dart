import '../../read/syntax/block_starts.dart';
import '../../read/syntax/characters.dart';
import '../../tree/blocks.dart';
import '../draft.dart';
import '../inline/line_starts.dart';

/// Where blocks sit, for the blank lines between them.
enum Spacing {
  /// In the note or a quote.
  blocks,

  /// Items of a tight list.
  tightItems,

  /// Items of a loose list.
  looseItems,

  /// Blocks in an item of a tight list.
  tightInItem,

  /// Blocks in an item of a loose list.
  looseInItem;

  bool get loose => this == looseItems || this == looseInItem;

  bool get betweenItems => this == tightItems || this == looseItems;
}

/// Whether a blank line must come between [before] and a block whose
/// first line reads [next] after the marks of the containers they share:
/// else [before] would take that line in (a quote's line, a paragraph's
/// lazy or setext line, a table's row, an HTML block's line).
bool blankNeeded(Draft before, String next, {required Spacing spacing}) {
  if (spacing.betweenItems || isBlankText(next)) return false;
  if (_isQuote(before) && _quoteLine.hasMatch(next)) return true;
  final leaf = switch (before) {
    TextDraft() || CodeDraft() || KeptDraft(block: LeafBlock()) => true,
    _ => false,
  };
  return switch (_lastLeafOf(before)) {
    _LastLeaf.paragraph || _LastLeaf.definitions =>
      leaf ? !endsParagraph(next) : !endsLazyParagraph(next),
    _LastLeaf.table =>
      leaf
          ? lineStartEscapeAt(next, first: true) == null
          : !endsLazyParagraph(next),
    _LastLeaf.openHtml => leaf,
    _LastLeaf.other || null => false,
  };
}

final _quoteLine = RegExp(r'^ {0,3}>');

bool _isQuote(Draft draft) => switch (draft) {
  QuoteDraft() || KeptDraft(block: QuoteBlock()) => true,
  _ => false,
};

/// What ends a block, for what it may take in.
enum _LastLeaf { paragraph, definitions, table, openHtml, other }

/// The kind of [draft]'s last leaf; `null` if it has none.
_LastLeaf? _lastLeafOf(Draft draft) => switch (draft) {
  TextDraft(level: null) => _LastLeaf.paragraph,
  TextDraft() || CodeDraft() => _LastLeaf.other,
  KeptDraft(block: final ContainerBlock container) =>
    switch (container.leaves.lastOrNull) {
      final leaf? => _leafKind(leaf),
      null => null,
    },
  KeptDraft(block: final LeafBlock leaf) => _leafKind(leaf),
  ListDraft(:final items) => items.isEmpty ? null : _lastLeafOf(items.last),
  ItemDraft(:final children) || QuoteDraft(:final children) =>
    children.isEmpty ? null : _lastLeafOf(children.last),
};

_LastLeaf _leafKind(LeafBlock leaf) => switch (leaf) {
  ParagraphBlock() => _LastLeaf.paragraph,
  DefinitionsBlock() => _LastLeaf.definitions,
  TableBlock() => _LastLeaf.table,
  HtmlBlock(:final lines) when _htmlKind(lines.first.content.trimLeft()) >= 6 =>
    _LastLeaf.openHtml,
  _ => _LastLeaf.other,
};

/// The start condition an HTML block's first line [rest] meets first.
int _htmlKind(String rest) => htmlBlockStarts.entries
    .firstWhere((start) => start.value.matchAsPrefix(rest) != null)
    .key;

/// Whether [leaf] takes in every line after it in its container: an HTML
/// block whose end condition no line of it meets. No block can follow it
/// there, which commands keep to.
bool takesInTheRest(LeafBlock leaf) => switch (leaf) {
  HtmlBlock(:final lines) => switch (htmlBlockEnds[_htmlKind(
    lines.first.content.trimLeft(),
  )]) {
    final end? => !lines.any((line) => end.hasMatch(line.content)),
    null => false,
  },
  _ => false,
};
