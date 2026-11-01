import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_masonry/truce_masonry.dart';

import '../../common/snack.dart';
import '../../document_page/ui/document_screen.dart';
import '../documents_wiring.dart';

/// [count] cards, each built by [card], in columns up to 240 wide, each as
/// tall as its text: the layout shared by every document grid. Only cards
/// near the screen are built.
Widget documentGrid(int count, Widget Function(int index) card) =>
    SliverMasonryGrid(
      itemCount: count,
      itemBuilder: (_, index) => card(index),
      maxColumnWidth: 240,
      spacing: 8,
    );

/// [cards] laid out as [documentGrid], all built at once, as a box: for a
/// part of a list that is built only near the screen, such as a section.
Widget documentGridBox(List<Widget> cards) => CustomScrollView(
  shrinkWrap: true,
  primary: false,
  physics: const NeverScrollableScrollPhysics(),
  slivers: [documentGrid(cards.length, (index) => cards[index])],
);

/// [card] in a document grid, which shows it once it is [ready]: when its
/// height is final, so it never grows on screen.
Widget gridCard(Widget card, {required bool ready}) =>
    MasonryItem(ready: ready, child: card);

/// Opens [document] in the editor, with its text as it is now; tells the
/// user if it can't be read.
Future<void> openDocument(
  BuildContext context,
  WidgetRef ref,
  Document document,
) async {
  final read = await ref
      .read(folderFilesProvider)
      .of(document.folder)
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
