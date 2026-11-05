import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/view/add_item_place.dart';
import 'package:truce_markdown/src/view/row_looks.dart';
import 'package:truce_markdown/src/view/rows.dart';

/// What Visual edit shows of [text], checked items in Done sections.
ViewRows _shown(String text) =>
    ViewRows(loadMarkdown(text).doc, done: DoneSections());

/// The looks of [view], Add item at [addItems].
List<RowLook> _looks(
  ViewRows view, {
  AddItemPlace addItems = AddItemPlace.top,
  NodeId? folded,
}) => RowLooks(view, addItems: addItems, folded: folded).looks;

List<Frame> _framesOf(RowLook look) => switch (look) {
  TextLook(:final frames) ||
  BlockLook(:final frames) ||
  RawTextLook(:final frames) ||
  AddItemLook(:final frames) ||
  DoneHeadingLook(:final frames) => frames,
};

/// Each look's quote bars, as (starts, ends).
List<List<(bool, bool)>> _bars(List<RowLook> looks) => [
  for (final look in looks)
    [
      for (final frame in _framesOf(look).whereType<QuoteFrame>())
        (frame.starts, frame.ends),
    ],
];

Iterable<DocBlock> _nodes(DocBlock node) => [
  node,
  if (node case DocContainer(:final children)) ...children.expand(_nodes),
];

void main() {
  const quotedChecklist = '> - [ ] a\n> - [x] b';

  test('Add item at the top starts the bar of the quote its list is in', () {
    final looks = _looks(_shown(quotedChecklist));

    expect(looks.map((look) => look.runtimeType), [
      AddItemLook,
      TextLook,
      DoneHeadingLook,
      TextLook,
    ]);
    expect(_bars(looks), [
      [(true, false)],
      [(false, false)],
      [(false, false)],
      [(false, true)],
    ]);
  });

  test('Add item at the bottom and the Done heading stay in the quote', () {
    final looks = _looks(
      _shown(quotedChecklist),
      addItems: AddItemPlace.bottom,
    );

    expect(looks.map((look) => look.runtimeType), [
      TextLook,
      AddItemLook,
      DoneHeadingLook,
      TextLook,
    ]);
    expect(_bars(looks), [
      [(true, false)],
      [(false, false)],
      [(false, false)],
      [(false, true)],
    ]);
  });

  test("a list's own rows are in no item", () {
    final looks = _looks(_shown(quotedChecklist));

    expect(_framesOf(looks.first).whereType<ItemFrame>(), isEmpty);
  });

  test('sibling quotes keep bars of their own', () {
    final looks = _looks(_shown('> a\n\n> b'));
    final quotes = [
      for (final look in looks) _framesOf(look).whereType<QuoteFrame>().single,
    ];

    expect(_bars(looks), [
      [(true, true)],
      [(true, true)],
    ]);
    expect(quotes.first.quote, isNot(quotes.last.quote));
  });

  test('a nested quote ends where its last row shows, inside the outer '
      'one', () {
    final looks = _looks(_shown('> a\n>\n> > b\n>\n> c'));

    expect(_bars(looks), [
      [(true, false)],
      [(false, false), (true, true)],
      [(false, true)],
    ]);
  });

  test("the bar ends at a dragged item's row while its subitems are "
      'folded', () {
    final shown = _shown('> - [ ] a\n>   - [ ] sub');
    final first = _nodes(shown.doc.root).whereType<ItemNode>().first;

    final looks = _looks(shown, addItems: AddItemPlace.top, folded: first.id);

    expect(_bars(looks), [
      [(true, false)],
      [(false, true)],
    ]);
  });
}
