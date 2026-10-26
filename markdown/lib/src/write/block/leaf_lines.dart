import 'dart:math';

import 'package:collection/collection.dart';

import '../../document_tree.dart';
import '../../read/syntax/block_starts.dart';
import '../../read/syntax/characters.dart';
import '../../tree/blocks.dart';
import '../../tree/inlines.dart';
import '../../visible/visible_text.dart';
import '../draft.dart';
import '../inline/inline_writing.dart';

/// A leaf's part of one line it writes, and the old line it rewrites, if
/// any: whose id it keeps, and its containers' bytes unless [newParts]
/// (where its own indent is written anew, which they must fit).
typedef OwnLine = ({SourceLine? old, String own, bool newParts});

/// Whether [line] of [leaf] is lazy: it lacks some of the containers'
/// marks its first line has. A lazy line stays lazy only in place.
bool isLazy(SourceLine line, LeafBlock leaf) =>
    line.prefix.length < leaf.lines.first.prefix.length;

/// Where [line]'s containers' parts end.
int prefixEndOf(SourceLine line) => line.prefix.lastOrNull?.end ?? 0;

/// The lines of [leaf] as they are, the first one's indent only if
/// [indentFirst].
List<OwnLine> keptLines(LeafBlock leaf, {bool indentFirst = true}) => [
  for (final (index, line) in leaf.lines.indexed)
    (
      old: line,
      own: switch (line.text.substring(prefixEndOf(line))) {
        final own when index == 0 && !indentFirst => own.trimLeft(),
        final own => own,
      },
      newParts: false,
    ),
];

/// Whether a heading of [level] whose text comes [from] leaves keeps
/// their setext style: one setext heading of level 1 or 2 (an empty one
/// is written ATX, as a setext heading cannot be empty).
bool keepsSetext(int? level, List<TextLeaf> from) => switch ((level, from)) {
  (1 || 2, [HeadingBlock(style: HeadingStyle.setext)]) => true,
  _ => false,
};

/// The lines that write [draft] in [tree]: its text in place of its old
/// leaves' text, as a paragraph, an ATX heading, or a setext heading if
/// it was one at level 1 or 2. Its lines rewrite its old leaves' lines
/// in order, keeping their indents: a first line's only if [indentFirst],
/// and its tab only [inPlace], in the same containers, where it still
/// spans as many columns. Its first line comes right after a [bullet]
/// marker if given.
List<OwnLine> textLines(
  TextDraft draft,
  DocumentTree tree, {
  required bool inPlace,
  bool indentFirst = true,
  String? bullet,
}) {
  final from = draft.from;
  final level = draft.level;
  final setext = keepsSetext(level, from) && draft.text.text.isNotEmpty;
  final atx = level != null && !setext;
  final olds = [for (final leaf in from) ...leaf.lines];
  final textOlds = setext ? olds.sublist(0, olds.length - 1) : olds;
  final leads = [
    for (final (index, old) in textOlds.indexed)
      (
        indent: switch (old.text.substring(
          prefixEndOf(old),
          old.contentStart,
        )) {
          final lead
              when index > 0 ||
                  (indentFirst && (inPlace || !lead.contains('\t'))) =>
            lead,
          _ => '',
        },
        lazy:
            inPlace &&
            isLazy(old, from.firstWhere((leaf) => leaf.lines.contains(old))),
      ),
  ];
  final source =
      inlineSource(
        old: [
          for (final leaf in from)
            for (final inline in leaf.text.inlines)
              atx ? _inOneLine(inline) : inline,
        ],
        oldText: from.fold(
          VisibleText.empty,
          (text, leaf) => text + visibleTextOf(leaf.text),
        ),
        text: draft.text,
        lines: atx ? TextLines.atxHeading : TextLines.paragraph,
        style: tree.style,
        definitions: tree.definitions,
        leads: leads,
        bullet: bullet,
      ) ??
      _unwritable(draft.text);
  if (atx) {
    final heading = switch (from) {
      [HeadingBlock(style: HeadingStyle.atx, level: final old, :final text)]
          when old == level =>
        text,
      _ => null,
    };
    // An empty heading's opener may lack the space text needs after it.
    final before = switch (heading?.before) {
      final old?
          when source.isEmpty || old.endsWith(' ') || old.endsWith('\t') =>
        old,
      final old? => '$old ',
      null => '${'#' * level} ',
    };
    // An empty heading's closing marks may touch its opener's spaces.
    final after = switch (heading?.after) {
      final old? when source.isNotEmpty && old.startsWith('#') => ' $old',
      final old => old ?? '',
    };
    final own = '${leads.firstOrNull?.indent ?? ''}$before$source$after';
    return [
      (
        old: olds.firstOrNull,
        newParts: false,
        own: source.isEmpty && heading == null ? own.trimRight() : own,
      ),
    ];
  }
  final split = source.split('\n');
  final trail = switch (from.lastOrNull) {
    HeadingBlock(style: HeadingStyle.atx) || null => '',
    final TextLeaf leaf => leaf.text.after.split('\n').first,
  };
  final content = [
    for (final (index, line) in split.indexed)
      (
        old: textOlds.elementAtOrNull(index),
        newParts: false,
        own:
            '${leads.elementAtOrNull(index)?.indent ?? ''}$line'
            '${index == split.length - 1 && index == textOlds.length - 1 ? trail : ''}',
      ),
  ];
  if (!setext) return content;
  final underline = olds.last;
  final char = level == 1 ? '=' : '-';
  final oldUnderline = underline.text.substring(prefixEndOf(underline));
  return [
    ...content,
    (
      old: underline,
      newParts: false,
      own: oldUnderline.trim().startsWith(char)
          ? oldUnderline
          : char * oldUnderline.trim().length,
    ),
  ];
}

/// [inline] in one line, as an ATX heading holds it; objects as they
/// are, which the text names by identity (the settled text has them in
/// one line).
Inline _inOneLine(Inline inline) => switch (inline) {
  HtmlInline() || ImageInline() => inline,
  _ => inOneLine(inline),
};

/// Text a command should never hand over: written plain, every
/// punctuation character escaped, so no text is lost.
String _unwritable(VisibleText text) {
  assert(false, 'no writing reads as $text');
  return text.text
      .split('')
      .map((char) => isAsciiPunctuation(char) ? '\\$char' : char)
      .join();
}

/// A line part whose indent holds a tab, which spans as many columns
/// only where its containers' parts stay as they were.
final _tabLead = RegExp(r'^ *\t');

/// The lines that write [draft]: its fences kept (grown where the code
/// holds a line that would close them, and a closing one added where it
/// must be [closed] and was not), unchanged code lines kept; if
/// [outdented], fences without their indent and their code lines anew.
List<OwnLine> codeLines(
  CodeDraft draft, {
  required bool inPlace,
  required bool closed,
  bool outdented = false,
}) {
  final block = draft.from;
  final olds = block.codeLines;
  final code = draft.code.isEmpty && olds.isEmpty
      ? <String>[]
      : draft.code.split('\n');
  String oldCode(SourceLine line) => '${' ' * line.tabColumns}${line.content}';
  String oldOwn(SourceLine line) => line.text.substring(prefixEndOf(line));
  final indent = switch (block.fenced) {
    true when outdented => '',
    true => RegExp(r'^ *').firstMatch(oldOwn(block.lines.first))![0]!,
    false => '    ',
  };
  OwnLine codeLine(SourceLine? old, String line) => switch (old) {
    final old?
        when oldCode(old) == line &&
            !(outdented && block.fenced) &&
            (inPlace || !_tabLead.hasMatch(oldOwn(old))) =>
      (old: old, own: oldOwn(old), newParts: false),
    _ => (
      old: old,
      own: '$indent$line',
      newParts: old != null && _tabLead.hasMatch(oldOwn(old)),
    ),
  };
  final lines = [
    for (final (index, line) in code.indexed)
      codeLine(olds.elementAtOrNull(index), line),
  ];
  final fence = block.fence;
  if (fence == null) return lines;
  final longest = code
      .map((line) => '$indent$line')
      .where(
        (line) =>
            line.length - line.trimLeft().length <= 3 &&
            closesFence(line.trimLeft(), fence[0], fence.length),
      )
      .map(
        (line) =>
            RegExp('^${RegExp.escape(fence[0])}+')
                .firstMatch(line.trimLeft())![0]!
                .length,
      )
      .maxOrNull;
  OwnLine fenceLine(SourceLine line) {
    final own = outdented ? oldOwn(line).trimLeft() : oldOwn(line);
    return (
      old: line,
      newParts: false,
      own: longest == null
          ? own
          : own.replaceFirst(fence[0] * fence.length, fence[0] * (longest + 1)),
    );
  }

  return [
    fenceLine(block.lines.first),
    ...lines,
    if (block.closed)
      fenceLine(block.lines.last)
    else if (closed)
      (
        old: null,
        newParts: false,
        own: '$indent${fence[0] * ((longest ?? fence.length - 1) + 1)}',
      ),
  ];
}

/// Whether an indented code block can hold [code]: blank lines at its
/// start or end, or none at all, would not read as its code.
bool indentedCanHold(String code) {
  final lines = code.split('\n');
  return !isBlankText(lines.first) && !isBlankText(lines.last);
}

/// The lines that write [code] of [block], an indented code block, as a
/// fenced one: as right after a block that would take it in, or where an
/// indented one cannot hold it.
/// Its code lines keep their old lines' ids.
List<OwnLine> fencedCodeLines(CodeBlock block, String code) {
  final lines = code.isEmpty ? const <String>[] : code.split('\n');
  final longest = lines
      .where((line) => line.length - line.trimLeft().length <= 3)
      .map((line) => RegExp('^`*').firstMatch(line.trimLeft())![0]!.length)
      .fold(0, max);
  final fence = '`' * max(3, longest + 1);
  return [
    (old: null, own: fence, newParts: false),
    for (final (index, line) in lines.indexed)
      (old: block.codeLines.elementAtOrNull(index), own: line, newParts: false),
    (old: null, own: fence, newParts: false),
  ];
}
