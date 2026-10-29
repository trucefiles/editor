import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../../document_page/ui/document_screen.dart';
import '../document.dart';
import '../document_files.dart';
import '../open_failure.dart';

/// [count] cards, each built by [card], in columns up to 240 wide, each
/// card as tall as its content: the layout shared by every document grid.
/// Only cards near the screen are built.
///
/// BUG (flutter_staggered_grid_view 0.7.0): once this grid has scrolled
/// fully off the top, it reports a wrong height, so whatever follows it
/// jumps and the scroll snaps back. Only use it as the last sliver; put
/// grids that something follows in [documentGridAtOnce].
Widget documentGrid(int count, Widget Function(int index) card) =>
    SliverMasonryGrid(
      gridDelegate: _columns,
      crossAxisSpacing: _spacing,
      mainAxisSpacing: _spacing,
      delegate: SliverChildBuilderDelegate(
        (_, index) => card(index),
        childCount: count,
      ),
    );

/// [cards] laid out as [documentGrid], all built at once.
///
/// TODO(etv): WORKAROUND, TEMPORARY. Exists only to avoid the bug noted
/// on [documentGrid]: a grid built at once never scrolls inside, so it never
/// hits it. Remove it, and the library, when our own masonry sliver
/// replaces flutter_staggered_grid_view (todo, after Phase 1).
Widget documentGridAtOnce(List<Widget> cards) =>
    SliverToBoxAdapter(child: documentGridBox(cards));

/// [cards] laid out as [documentGrid], all built at once, as a box: for a
/// part of a list that is built only near the screen, such as a section.
Widget documentGridBox(List<Widget> cards) => MasonryGridView.custom(
  gridDelegate: _columns,
  crossAxisSpacing: _spacing,
  mainAxisSpacing: _spacing,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: EdgeInsets.zero,
  childrenDelegate: SliverChildListDelegate(cards),
);

const _columns = SliverSimpleGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 240,
);
const _spacing = 8.0;

/// Opens [document] in the editor, with its text as it is now; tells the
/// user if it can't be read.
Future<void> openDocument(
  BuildContext context,
  WidgetRef ref,
  Document document,
) async {
  final read = await ref
      .read(documentFilesProvider(document.folder))
      .reload(document);
  if (!context.mounted) return;
  switch (read) {
    case Ok(value: final opened):
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => DocumentScreen(opened)),
      );
    case Err(:final error):
      showSnack(context, "This document can't be opened. ${error.text}");
  }
}
