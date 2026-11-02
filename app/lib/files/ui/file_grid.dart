import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_masonry/truce_masonry.dart';

import '../../common/snack.dart';
import '../../file_page/ui/file_screen.dart';
import '../files_wiring.dart';

/// [count] cards, each built by [card], in columns up to 240 wide, each as
/// tall as its text: the layout shared by every file grid. Only cards
/// near the screen are built.
Widget fileGrid(int count, Widget Function(int index) card) =>
    SliverMasonryGrid(
      itemCount: count,
      itemBuilder: (_, index) => card(index),
      maxColumnWidth: 240,
      spacing: 8,
    );

/// [cards] laid out as [fileGrid], all built at once, as a box: for a
/// part of a list that is built only near the screen, such as a section.
Widget fileGridBox(List<Widget> cards) => CustomScrollView(
  shrinkWrap: true,
  primary: false,
  physics: const NeverScrollableScrollPhysics(),
  slivers: [fileGrid(cards.length, (index) => cards[index])],
);

/// [card] in a file grid, which shows it once it is [ready]: when its
/// height is final, so it never grows on screen.
Widget gridCard(Widget card, {required bool ready}) =>
    MasonryItem(ready: ready, child: card);

/// Opens [file] in the editor, with its text as it is now; tells the
/// user if it can't be read.
Future<void> openFile(
  BuildContext context,
  WidgetRef ref,
  ListedFile file,
) async {
  final read = await ref.read(fileAccessProvider).of(file.folder).reload(file);
  if (!context.mounted) return;
  switch (read) {
    case Ok(value: final opened):
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => FileScreen(opened)),
      );
    case Err(:final error):
      showSnack(context, "This file can't be opened. ${error.text}");
  }
}
