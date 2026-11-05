import '../../../common/unchanged_ends.dart';

/// How one text became another: the stretch from [start] that went
/// ([removed]) and what came in its place ([added]), found by matching
/// both texts from their starts and their ends.
typedef TextChange = ({int start, String removed, String added});

/// How [before] became [after]. Where the change sits in repeated text
/// (`abab` to `ab`) is a guess, which is fine for grouping undo steps
/// and placing the caret.
TextChange textChange(String before, String after) {
  final same = unchangedEnds(before.codeUnits, after.codeUnits);
  final start = _wholeCharacterStart(before, same.start);
  final end = _wholeCharacterEnd(before, same.end);
  return (
    start: start,
    removed: before.substring(start, before.length - end),
    added: after.substring(start, after.length - end),
  );
}

/// [start], moved back off the second half of a character made of two
/// code units (e.g. an emoji), so a change never cuts one in two.
int _wholeCharacterStart(String text, int start) =>
    start > 0 && _isLead(text.codeUnitAt(start - 1)) ? start - 1 : start;

/// [end], counted from [text]'s end, moved likewise.
int _wholeCharacterEnd(String text, int end) =>
    end > 0 && _isTrail(text.codeUnitAt(text.length - end)) ? end - 1 : end;

/// [text] with [change] made in it: its removed text, at its start,
/// replaced by its added text. Any other text there is a bug: the change
/// is not of this text.
String applyChange(String text, TextChange change) {
  final (:start, :removed, :added) = change;
  final end = start + removed.length;
  if (end > text.length || !text.startsWith(removed, start)) {
    throw StateError('a change applied to a text it is not of');
  }
  return text.replaceRange(start, end, added);
}

/// [change] taken back: what it added goes, what it removed comes back.
TextChange reversedChange(TextChange change) =>
    (start: change.start, removed: change.added, added: change.removed);

bool _isLead(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isTrail(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// [first], then [next] on the text [first] left, as one change; [next]
/// must touch what [first] added (as typing that goes on does).
TextChange followedBy(TextChange first, TextChange next) {
  final firstEnd = first.start + first.added.length;
  final nextEnd = next.start + next.removed.length;
  assert(
    next.start <= firstEnd && nextEnd >= first.start,
    'the changes are apart',
  );
  final start = first.start < next.start ? first.start : next.start;
  // What [next] removed before and after the text [first] added.
  final ahead = first.start > next.start
      ? next.removed.substring(0, first.start - next.start)
      : '';
  final behind = nextEnd > firstEnd
      ? next.removed.substring(next.removed.length - (nextEnd - firstEnd))
      : '';
  return (
    start: start,
    removed: '$ahead${first.removed}$behind',
    added: '$ahead${first.added}$behind'.replaceRange(
      next.start - start,
      nextEnd - start,
      next.added,
    ),
  );
}
