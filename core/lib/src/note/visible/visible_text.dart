import 'package:collection/collection.dart';

import '../tree/inlines.dart';
import 'formatting.dart';

/// The character an image or inline HTML shows as in visible text.
const objectCharacter = '￼';

/// One piece of visible text, with its formatting.
sealed class VisiblePiece {
  const VisiblePiece(this.formatting);

  final Formatting formatting;

  /// The characters it shows.
  String get shown;

  int get length => shown.length;

  VisiblePiece withFormatting(Formatting formatting);

  /// Whether it shows the same as [other], formatting included.
  bool sameAs(VisiblePiece other);
}

/// Text, as it reads: no marks, no escapes.
final class TextPiece extends VisiblePiece {
  TextPiece(this.text, [Formatting? formatting])
    : super(formatting ?? Formatting.plain);

  final String text;

  @override
  String get shown => text;

  @override
  TextPiece withFormatting(Formatting formatting) =>
      TextPiece(text, formatting);

  @override
  bool sameAs(VisiblePiece other) =>
      other is TextPiece &&
      other.text == text &&
      other.formatting == formatting;

  @override
  String toString() => 'Text($text, $formatting)';
}

/// A line break that shows as a space: text wrapped in the file.
final class SoftBreakPiece extends VisiblePiece {
  SoftBreakPiece([Formatting? formatting, this.read])
    : super(formatting ?? Formatting.plain);

  /// The break it was read as; `null` for a new one.
  final SoftBreakInline? read;

  @override
  String get shown => ' ';

  @override
  SoftBreakPiece withFormatting(Formatting formatting) =>
      SoftBreakPiece(formatting, read);

  @override
  bool sameAs(VisiblePiece other) =>
      other is SoftBreakPiece && other.formatting == formatting;

  @override
  String toString() => 'SoftBreak';
}

/// A line break that shows as one.
final class HardBreakPiece extends VisiblePiece {
  HardBreakPiece([Formatting? formatting, this.read])
    : super(formatting ?? Formatting.plain);

  /// The break it was read as; `null` for a new one.
  final HardBreakInline? read;

  @override
  String get shown => '\n';

  @override
  HardBreakPiece withFormatting(Formatting formatting) =>
      HardBreakPiece(formatting, read);

  @override
  bool sameAs(VisiblePiece other) =>
      other is HardBreakPiece && other.formatting == formatting;

  @override
  String toString() => 'HardBreak';
}

/// An image or inline HTML: one character that stands for [inline],
/// which is kept as written.
final class ObjectPiece extends VisiblePiece {
  ObjectPiece(this.inline, [Formatting? formatting])
    : super(formatting ?? Formatting.plain);

  /// An [ImageInline] or [HtmlInline].
  final Inline inline;

  @override
  String get shown => objectCharacter;

  @override
  ObjectPiece withFormatting(Formatting formatting) =>
      ObjectPiece(inline, formatting);

  @override
  bool sameAs(VisiblePiece other) =>
      other is ObjectPiece &&
      identical(other.inline, inline) &&
      other.formatting == formatting;

  @override
  String toString() => 'Object(${inline.source})';
}

/// What a text leaf shows: its characters and their formatting, without
/// marks. Immutable; text pieces of one formatting are joined.
final class VisibleText {
  VisibleText(Iterable<VisiblePiece> pieces) : pieces = _joined(pieces);

  static final empty = VisibleText(const []);

  final List<VisiblePiece> pieces;

  late final String text = pieces.map((piece) => piece.shown).join();

  int get length => text.length;

  bool get isEmpty => pieces.isEmpty;

  /// Where each piece starts.
  late final List<int> _starts = () {
    var end = 0;
    return [for (final piece in pieces) (end += piece.length) - piece.length];
  }();

  /// The index of the piece the character at [offset] is in.
  int _pieceAt(int offset) =>
      (lowerBound(_starts, offset + 1) - 1).clamp(0, pieces.length - 1);

  /// The formatting of the character at [offset].
  Formatting formattingAt(int offset) =>
      pieces[_pieceAt(offset)].formatting;

  /// The characters from [from] to [to].
  VisibleText slice(int from, int to) {
    if (from >= to) return empty;
    final first = _pieceAt(from);
    final last = _pieceAt(to - 1);
    return VisibleText([
      for (var index = first; index <= last; index++)
        _cut(index, from - _starts[index], to - _starts[index]),
    ]);
  }

  /// Piece [index] cut to its characters from [from] to [to]: only text
  /// pieces have more than one.
  VisiblePiece _cut(int index, int from, int to) => switch (pieces[index]) {
    TextPiece(:final text, :final formatting) => TextPiece(
      text.substring(from.clamp(0, text.length), to.clamp(0, text.length)),
      formatting,
    ),
    final piece => piece,
  };

  /// This text with the characters from [from] to [to] replaced by
  /// [insert].
  VisibleText replaced(int from, int to, VisibleText insert) => VisibleText([
    ...slice(0, from).pieces,
    ...insert.pieces,
    ...slice(to, length).pieces,
  ]);

  VisibleText operator +(VisibleText other) =>
      VisibleText([...pieces, ...other.pieces]);

  /// This text with the formatting of the characters from [from] to [to]
  /// changed by [change].
  VisibleText reformatted(
    int from,
    int to,
    Formatting Function(Formatting formatting) change,
  ) => replaced(
    from,
    to,
    VisibleText([
      for (final piece in slice(from, to).pieces)
        piece.withFormatting(change(piece.formatting)),
    ]),
  );

  /// The pieces with the offsets they start at.
  Iterable<(int, VisiblePiece)> get placedPieces => IterableZip([
    _starts,
    pieces,
  ]).map((pair) => (pair[0] as int, pair[1] as VisiblePiece));

  /// Whether the character at [offset] shows the same as [other]'s at
  /// [otherOffset], formatting included.
  bool sameCharacter(int offset, VisibleText other, int otherOffset) {
    final piece = pieces[_pieceAt(offset)];
    final otherPiece = other.pieces[other._pieceAt(otherOffset)];
    return switch ((piece, otherPiece)) {
      (TextPiece(), TextPiece()) =>
        text[offset] == other.text[otherOffset] &&
            piece.formatting == otherPiece.formatting,
      _ => piece.sameAs(otherPiece),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is VisibleText &&
      other.pieces.length == pieces.length &&
      IterableZip([
        pieces,
        other.pieces,
      ]).every((pair) => pair[0].sameAs(pair[1]));

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'VisibleText($pieces)';

  static List<VisiblePiece> _joined(Iterable<VisiblePiece> pieces) {
    final joined = <VisiblePiece>[];
    for (final piece in pieces) {
      final last = joined.lastOrNull;
      if (piece is TextPiece && piece.text.isEmpty) continue;
      if (piece is TextPiece &&
          last is TextPiece &&
          last.formatting == piece.formatting) {
        joined[joined.length - 1] = TextPiece(
          last.text + piece.text,
          piece.formatting,
        );
      } else {
        joined.add(piece);
      }
    }
    return List.unmodifiable(joined);
  }
}

/// What [text] shows: its inline content as visible text.
VisibleText visibleTextOf(InlineText text) =>
    VisibleText(_pieces(text.inlines, Formatting.plain));

Iterable<VisiblePiece> _pieces(List<Inline> inlines, Formatting formatting) =>
    inlines.expand(
      (inline) => switch (inline) {
        TextInline(:final literal) => [TextPiece(literal, formatting)],
        SoftBreakInline() => [SoftBreakPiece(formatting, inline)],
        HardBreakInline() => [HardBreakPiece(formatting, inline)],
        CodeInline(:final literal) => [
          TextPiece(literal, formatting.withFormat(TextFormat.code, on: true)),
        ],
        HtmlInline() || ImageInline() => [ObjectPiece(inline, formatting)],
        EmphasisInline(:final children) => _pieces(
          children,
          formatting.withFormat(TextFormat.emphasis, on: true),
        ),
        StrongInline(:final children) => _pieces(
          children,
          formatting.withFormat(TextFormat.strong, on: true),
        ),
        StrikeInline(:final children) => _pieces(
          children,
          formatting.withFormat(TextFormat.strike, on: true),
        ),
        LinkInline(:final children) => _pieces(
          children,
          formatting.withLink(LinkMark.of(inline)),
        ),
      },
    );
