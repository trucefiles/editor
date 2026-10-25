import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import 'text_places.dart';

/// The level the heading button gives text of [level] (`null` for a
/// paragraph): none, 1, 2, 3, then none again; levels 4 to 6 go to none.
int? nextHeadingLevel(int? level) => switch (level) {
  null => 1,
  1 => 2,
  2 => 3,
  _ => null,
};

/// The text at [at]'s place made a heading of [level], or a paragraph if
/// `null`; a heading in one line shows its line breaks as spaces.
Edit setHeading(ShownDocument document, Place at, int? level) {
  final change = withText(
    document,
    at.slot,
    document.textOf(at.slot),
    document.tree.freshBlockIds.iterator,
    heading: (level: level),
  );
  return Edit(
    replaced: change.replaced,
    gaps: change.gaps,
    tails: change.tails,
    selection: TextSelection.caret(Place(change.slot, at.offset)),
  );
}
