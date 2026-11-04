import 'dart:math';

import 'package:flutter/widgets.dart';

/// Keeps a page's content in one centered column on wide windows, so
/// labels and their values stay close together; on narrow screens such as
/// phones the content keeps the full width.
///
/// The column is at most [maxWidth] logical pixels wide, grown with the
/// text size, so large text doesn't get cramped. [builder] gets the
/// padding that keeps the content in the column: the space at each side,
/// plus the screen's top and bottom insets that a list adds on its own
/// when it is given no padding. The padding goes inside the scroll view,
/// so the scroll bar stays at the window's edge and the wheel scrolls
/// over the sides too.
class PageWidth extends StatelessWidget {
  const PageWidth({required this.builder, super.key});

  /// The widest the column gets at the normal text size (Material's
  /// common width for settings and forms on large screens).
  static const maxWidth = 640.0;

  final Widget Function(BuildContext context, EdgeInsets padding) builder;

  /// The space at each side of the column in a page [width] wide.
  static double sideOf(double width, TextScaler textScaler) =>
      max(0, (width - textScaler.scale(maxWidth)) / 2);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = sideOf(
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
      );
      final insets = MediaQuery.paddingOf(context);
      return builder(
        context,
        EdgeInsets.fromLTRB(side, insets.top, side, insets.bottom),
      );
    },
  );
}
