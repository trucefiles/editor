import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/snack.dart';
import '../../document_page/ui/document_screen.dart';
import '../documents_wiring.dart';
import 'card_frame.dart';

/// [count] cards, each built by [card], in columns up to 240 wide, all
/// [cardHeight] tall: the layout shared by every document grid. Only cards
/// near the screen are built.
Widget documentGrid(int count, Widget Function(int index) card) => Builder(
  builder: (context) => SliverGrid(
    gridDelegate: _columns(context),
    delegate: SliverChildBuilderDelegate(
      (_, index) => card(index),
      childCount: count,
    ),
  ),
);

/// [cards] laid out as [documentGrid], all built at once, as a box: for a
/// part of a list that is built only near the screen, such as a section.
Widget documentGridBox(List<Widget> cards) => Builder(
  builder: (context) => GridView(
    gridDelegate: _columns(context),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: cards,
  ),
);

SliverGridDelegate _columns(BuildContext context) =>
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisSpacing: _spacing,
      crossAxisSpacing: _spacing,
      mainAxisExtent: cardHeight(context),
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
