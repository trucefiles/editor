import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

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
