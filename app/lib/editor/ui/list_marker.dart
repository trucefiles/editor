import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../note_metrics.dart';
import '../note_text_styles.dart';

/// The marker of a list item of [kind], the same in every mode: its box,
/// [checked] or not, which [onToggle] checks or unchecks; its bullet; or
/// its [number]; text in [style]. Every kind ends the same gap before the
/// text (a box where it is drawn), as lists are drawn on the web, so
/// numbers line up on their dot; centered on the item's first line of
/// text. Sized by the [NoteMetrics] of its context, the box too.
class ListMarker extends StatelessWidget {
  const ListMarker(
    this.kind, {
    required this.style,
    this.checked = false,
    this.number = 1,
    this.onToggle,
    super.key,
  });

  final ListKind kind;
  final bool checked;
  final int number;
  final TextStyle style;

  /// Toggles the box; without it, the box only shows its state.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final metrics = NoteMetrics.of(context);
    return SizedBox(
      width: metrics.markerWidth,
      height: NoteTextStyles.lineHeightOf(
        style,
        MediaQuery.textScalerOf(context),
      ),
      child: CustomSingleChildLayout(
        delegate: _MarkerLayout(
          Directionality.of(context),
          gap: metrics.markerGap,
          // A checkbox draws its box in the middle of its tap area.
          drawnWidth: kind == ListKind.checkbox
              ? Checkbox.width * metrics.scale
              : null,
        ),
        child: switch (kind) {
          ListKind.checkbox => Transform.scale(
            scale: metrics.scale,
            child: _box(Theme.of(context).colorScheme),
          ),
          ListKind.bullet => Text('•', style: style),
          ListKind.numbered => Text('$number.', style: style),
        },
      ),
    );
  }

  /// The box, in the same colors whether or not it toggles: where it
  /// can't (Read, a dragged copy), it shows its state, it isn't disabled.
  Widget _box(ColorScheme colors) => Checkbox(
    value: checked,
    // As high as a line of text, so lists stay compact.
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    fillColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colors.primary
          : Colors.transparent,
    ),
    checkColor: colors.onPrimary,
    side: WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? const BorderSide(width: 0, color: Colors.transparent)
          : BorderSide(width: 2, color: colors.onSurfaceVariant),
    ),
    onChanged: switch (onToggle) {
      final toggle? => (_) => toggle(),
      null => null,
    },
  );
}

/// A marker as large as it wants, placed so that what it draws, the
/// [drawnWidth] around its middle (all of it if `null`), ends [gap]
/// before the end of its slot; centered in the slot's height.
class _MarkerLayout extends SingleChildLayoutDelegate {
  const _MarkerLayout(this.direction, {required this.gap, this.drawnWidth});

  final TextDirection direction;
  final double gap;
  final double? drawnWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final margin = (childSize.width - (drawnWidth ?? childSize.width)) / 2;
    final fromEnd = gap - margin;
    return Offset(switch (direction) {
      TextDirection.ltr => size.width - fromEnd - childSize.width,
      TextDirection.rtl => fromEnd,
    }, (size.height - childSize.height) / 2);
  }

  @override
  bool shouldRelayout(_MarkerLayout oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.gap != gap ||
      oldDelegate.drawnWidth != drawnWidth;
}
