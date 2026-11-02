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

bool _isLead(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isTrail(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
