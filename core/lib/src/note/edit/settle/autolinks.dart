import 'package:collection/collection.dart';

import '../../read/syntax/extended_autolinks.dart';
import '../../tree/inlines.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';

/// [text] with its bare links as GitHub Flavored Markdown reads them:
/// `www.` and scheme urls and email addresses in text outside code and
/// links are links, and nothing else is a bare link. A link found where
/// one was in [was], which shows the same characters, keeps its mark.
VisibleText withAutolinks(VisibleText text, {VisibleText? was}) {
  final old = _bareLinks(was ?? text);
  final bare = withoutAutolinks(text);
  return _runs(bare)
      .expand((run) => _foundIn(bare.text, run))
      .fold(bare, (text, found) {
        final mark =
            old
                .firstWhereOrNull(
                  (link) =>
                      link.start == found.start &&
                      link.end == found.end &&
                      link.mark.destination == found.destination,
                )
                ?.mark ??
            LinkMark(
              destination: found.destination,
              style: LinkStyle.extendedAutolink,
            );
        return text.reformatted(
          found.start,
          found.end,
          (formatting) => formatting.withLink(mark),
        );
      });
}

/// [text] with no bare links: their text is plain text.
VisibleText withoutAutolinks(VisibleText text) => _bareLinks(text).fold(
  text,
  (text, link) => text.reformatted(
    link.start,
    link.end,
    (formatting) => formatting.withLink(null),
  ),
);

typedef _Link = ({int start, int end, LinkMark mark});

/// The bare links [text] holds, in order.
List<_Link> _bareLinks(VisibleText text) {
  final links = <_Link>[];
  for (final (offset, piece) in text.placedPieces) {
    final mark = piece.formatting.link;
    if (mark == null || mark.style != LinkStyle.extendedAutolink) continue;
    final last = links.lastOrNull;
    if (last != null && identical(last.mark, mark) && last.end == offset) {
      links.last = (start: last.start, end: offset + piece.length, mark: mark);
    } else {
      links.add((start: offset, end: offset + piece.length, mark: mark));
    }
  }
  return links;
}

typedef _Run = ({int start, int end, bool mayStartLink});

/// The stretches of [text] a bare link may be found in: text of one
/// formatting outside code and links, with whether a link may start at
/// its start. In the file it then follows a line start, a line break or
/// a delimiter, which a link may follow, or code, a link or an object,
/// which it may not.
Iterable<_Run> _runs(VisibleText text) => text.placedPieces.indexed
    .where((entry) => _mayHoldLink(entry.$2.$2))
    .map((entry) {
      final (index, (offset, piece)) = entry;
      return (
        start: offset,
        end: offset + piece.length,
        mayStartLink: switch (index == 0 ? null : text.pieces[index - 1]) {
          null || SoftBreakPiece() || HardBreakPiece() => true,
          final TextPiece before => _mayHoldLink(before),
          ObjectPiece() => false,
        },
      );
    });

bool _mayHoldLink(VisiblePiece piece) => switch (piece) {
  TextPiece(:final formatting) =>
    formatting.link == null && !formatting.has(TextFormat.code),
  _ => false,
};

/// The bare links in [run] of [text], at their offsets in [text].
Iterable<FoundLink> _foundIn(String text, _Run run) {
  // What the run follows in the file decides whether a link may start at
  // its start: a space stands for what may precede one, a NUL for what
  // may not.
  final lead = run.mayStartLink ? ' ' : '\u0000';
  final shift = run.start - lead.length;
  return findExtendedAutolinks(
    '$lead${text.substring(run.start, run.end)}',
    lead.length,
    lead.length + run.end - run.start,
  ).map(
    (found) => (
      start: found.start + shift,
      end: found.end + shift,
      destination: found.destination,
    ),
  );
}
