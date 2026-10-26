import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../documents/ui/document_screen.dart';
import '../note.dart';

/// [cards] in columns up to 240 wide, each card as tall as its content:
/// the layout shared by every note grid. Only cards near the screen are
/// built.
///
/// BUG (flutter_staggered_grid_view 0.7.0): once this grid has scrolled
/// fully off the top, it reports a wrong height, so whatever follows it
/// jumps and the scroll snaps back. Only use it as the last sliver; put
/// grids that something follows in [noteGridAtOnce].
Widget noteGrid(List<Widget> cards) => SliverMasonryGrid(
  gridDelegate: _columns,
  crossAxisSpacing: _spacing,
  mainAxisSpacing: _spacing,
  delegate: SliverChildListDelegate(cards),
);

/// [cards] laid out as [noteGrid], all built at once.
///
/// TODO(etv): WORKAROUND, TEMPORARY. Exists only to avoid the bug noted
/// on [noteGrid]: a grid built at once never scrolls inside, so it never
/// hits it. Remove it, and the library, when our own masonry sliver
/// replaces flutter_staggered_grid_view (todo, after Phase 1).
Widget noteGridAtOnce(List<Widget> cards) => SliverToBoxAdapter(
  child: MasonryGridView.custom(
    gridDelegate: _columns,
    crossAxisSpacing: _spacing,
    mainAxisSpacing: _spacing,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    childrenDelegate: SliverChildListDelegate(cards),
  ),
);

const _columns = SliverSimpleGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
);
const _spacing = 8.0;

/// Opens [note] in the editor.
Future<void> openNote(BuildContext context, Note note) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => DocumentScreen(note)),
);
