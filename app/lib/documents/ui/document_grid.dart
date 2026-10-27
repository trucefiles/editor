import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../document_page/ui/document_screen.dart';
import '../document.dart';

/// [cards] in columns up to 240 wide, each card as tall as its content:
/// the layout shared by every document grid. Only cards near the screen are
/// built.
///
/// BUG (flutter_staggered_grid_view 0.7.0): once this grid has scrolled
/// fully off the top, it reports a wrong height, so whatever follows it
/// jumps and the scroll snaps back. Only use it as the last sliver; put
/// grids that something follows in [documentGridAtOnce].
Widget documentGrid(List<Widget> cards) => SliverMasonryGrid(
  gridDelegate: _columns,
  crossAxisSpacing: _spacing,
  mainAxisSpacing: _spacing,
  delegate: SliverChildListDelegate(cards),
);

/// [cards] laid out as [documentGrid], all built at once.
///
/// TODO(etv): WORKAROUND, TEMPORARY. Exists only to avoid the bug noted
/// on [documentGrid]: a grid built at once never scrolls inside, so it never
/// hits it. Remove it, and the library, when our own masonry sliver
/// replaces flutter_staggered_grid_view (todo, after Phase 1).
Widget documentGridAtOnce(List<Widget> cards) => SliverToBoxAdapter(
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

/// Opens [document] in the editor.
Future<void> openNote(BuildContext context, Document document) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DocumentScreen(document)),
    );
