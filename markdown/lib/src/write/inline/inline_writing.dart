import '../../tree/blocks.dart';
import '../../tree/document_style.dart';
import '../../tree/inlines.dart';
import '../../visible/visible_text.dart';
import 'escaping.dart';
import 'inline_splice.dart';

export 'escaping.dart' show TextLines;

/// The inline source that writes [text] in place of [old] (which shows
/// as [oldText]): the change spliced in, escaped where needed, new spans
/// in [style]. Where the spliced change cannot read as [text] (old spans
/// around it clash with it), fewer spans around it are kept, down to
/// writing all of [old] anew with its characters' spelling, then all of
/// [text] anew, line breaks and shortcut references too. Its lines are
/// written after [leads], by line, the first right after a [bullet]
/// marker if given. `null` if [text] cannot be written at all (see
/// [canWrite]).
String? inlineSource({
  required List<Inline> old,
  required VisibleText oldText,
  required VisibleText text,
  required TextLines lines,
  required DocumentStyle style,
  required Map<String, LinkDefinition> definitions,
  List<LineLead> leads = const [],
  String? bullet,
}) =>
    [
          for (final levels in [null, ..._fewerLevels])
            () => spliceInlines(old, oldText, text, style, keptLevels: levels),
          () => spliceInlines(old, oldText, text, style, whole: true),
          () => spliceInlines(
            const [],
            VisibleText.empty,
            _withNewBreaks(text),
            style,
            anew: true,
          ),
        ]
        .map(
          (tokens) => escapedSource(
            tokens(),
            text,
            lines: lines,
            definitions: definitions,
            leads: leads,
            bullet: bullet,
          ),
        )
        .nonNulls
        .firstOrNull;

/// [text] with its hard breaks new, so they take the new spelling (a
/// kept trailing-spaces break cannot start a line).
VisibleText _withNewBreaks(VisibleText text) => VisibleText([
  for (final piece in text.pieces)
    switch (piece) {
      HardBreakPiece(:final formatting) => HardBreakPiece(formatting),
      _ => piece,
    },
]);

/// How many spans around a change a splice keeps when keeping all fails:
/// deep nesting is rare, so a few levels cover it.
const _fewerLevels = [2, 1, 0];

/// Whether [text] can be written as a leaf's inline content, so that it
/// reads back as [text]. Commands keep leaves' text so.
bool canWrite(
  VisibleText text, {
  TextLines lines = TextLines.paragraph,
  Map<String, LinkDefinition> definitions = const {},
}) =>
    inlineSource(
      old: const [],
      oldText: VisibleText.empty,
      text: text,
      lines: lines,
      style: const DocumentStyle(),
      definitions: definitions,
    ) !=
    null;
