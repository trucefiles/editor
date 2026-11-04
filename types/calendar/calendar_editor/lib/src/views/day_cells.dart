import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import 'health_days.dart';

/// How each day of the month view is shaded: weekends lightly, and the
/// cycle days of [health] as [CycleLegend] explains them; today always
/// outlined in the primary color, whatever else it shows.
MonthDayCellBuilder dayCells(HealthDays<Object?> health) => (context, details) {
  final colors = Theme.of(context).colorScheme;
  final day = health.of(details.date);
  final weekend = details.date.weekday >= DateTime.saturday;
  return Container(
    color: switch (day) {
      (period: true, likelyPeriod: _, fertile: _) => colors.errorContainer,
      (period: _, likelyPeriod: true, fertile: _) when likelyFill(colors) != null => likelyFill(colors),
      (period: _, likelyPeriod: _, fertile: true) => colors.tertiaryContainer,
      _ when weekend => colors.onSurface.withValues(alpha: 0.04),
      _ => null,
    },
    foregroundDecoration: details.isToday
        ? BoxDecoration(border: Border.all(color: colors.primary, width: 2))
        : null,
    child: day.likelyPeriod
        ? CustomPaint(
            painter: likelyStripes(colors),
            child: const SizedBox.expand(),
          )
        : null,
  );
};

/// A day's number in the month view, made smaller where its cell is too
/// narrow for it (very large text), never broken over two lines. Each
/// shrinks as a two-digit number would, so all show at one size.
Widget dayNumber(BuildContext context, DateTime date) => FittedBox(
  fit: BoxFit.scaleDown,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: MonthDayHeader(date: DateTime(2000, 1, 30)),
      ),
      MonthDayHeader(date: date),
    ],
  ),
);

/// Thin diagonal lines in [color] over the whole box: a day that is
/// likely, not known.
class Stripes extends CustomPainter {
  const Stripes(this.color, [this._gap = 6.0]);

  final Color color;

  final double _gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    // Lines from bottom left to top right, one every gap, across the box.
    for (var x = -size.height; x < size.width; x += _gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(Stripes old) => old.color != color;
}

/// What the cycle marks of the month view mean.
class CycleLegend extends StatelessWidget {
  const CycleLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    Widget item(BoxDecoration? look, String text, {Stripes? stripes}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: look,
          child: CustomPaint(painter: stripes),
        ),
        const SizedBox(width: 4),
        Text(text, style: small),
      ],
    );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(BoxDecoration(color: colors.errorContainer), 'Period'),
        item(BoxDecoration(color: likelyFill(colors)), 'Likely next period', stripes: likelyStripes(colors)),
        item(BoxDecoration(color: colors.tertiaryContainer), 'Likely fertile'),
      ],
    );
  }
}

// SAMPLE ONLY: which look the likely period days get.
var debugLikelyLook = 0;
// Light: pale error-container fill. Dark: light red (the error color) at low
// strength, so it reads as light red over the dark background.
const _looks = [
  (light: 0.3, dark: 0.6, lines: 0.2, gap: 12.0),
  (light: 0.3, dark: 0.85, lines: 0.2, gap: 12.0),
];
Color? likelyFill(ColorScheme colors) => Color.alphaBlend(
  colors.brightness == Brightness.dark
      ? (debugLikelyLook == 0 ? const Color(0xFFF48FB1) : const Color(0xFFF8BBD0))
          .withValues(alpha: _looks[debugLikelyLook].dark)
      : colors.errorContainer.withValues(alpha: _looks[debugLikelyLook].light),
  colors.surface,
);
Stripes likelyStripes(ColorScheme colors) => Stripes(
  colors.error.withValues(alpha: _looks[debugLikelyLook].lines),
  _looks[debugLikelyLook].gap,
);
