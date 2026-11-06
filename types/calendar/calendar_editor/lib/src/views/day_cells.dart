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
      (period: _, likelyPeriod: true, fertile: _) => likelyPeriodFill(colors),
      (period: _, likelyPeriod: _, fertile: true) => colors.tertiaryContainer,
      _ when weekend => colors.onSurface.withValues(alpha: 0.04),
      _ => null,
    },
    foregroundDecoration: details.isToday
        ? BoxDecoration(border: Border.all(color: colors.primary, width: 2))
        : null,
    child: day.likelyPeriod
        ? CustomPaint(
            painter: Stripes.likelyPeriod(colors),
            child: const SizedBox.expand(),
          )
        : null,
  );
};

/// The day numbers of the month view, each made smaller where its cell
/// is too narrow for it (very large text), never broken over two lines.
/// Each shrinks as a two-digit number would, so all show at one size:
/// each is laid out [twoDigits] wide ([twoDigitsWidth]).
MonthDayHeaderBuilder dayNumbers(double twoDigits) =>
    (context, date) => FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: twoDigits,
        child: Center(child: MonthDayHeader(date: date)),
      ),
    );

/// How wide a two-digit day number is in [context]: its text and the
/// padding of kalender's day number button (Material's default 8 on each
/// side). Worked out from the text, as a hidden two-digit number in each
/// cell cost as much as the numbers shown.
double twoDigitsWidth(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(text: '30', style: DefaultTextStyle.of(context).style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width + 2 * 8;
  painter.dispose();
  return width;
}

Color likelyPeriodFill(ColorScheme colors) =>
    Color.alphaBlend(switch (colors.brightness) {
      Brightness.light => colors.errorContainer.withValues(alpha: 0.3),
      Brightness.dark => const Color(0xFFF48FB1).withValues(alpha: 0.6),
    }, colors.surface);

/// Thin, faint diagonal lines in [color] over the whole box: a day that
/// is likely, not known.
class Stripes extends CustomPainter {
  const Stripes(this.color);

  /// The lines over a day likely in a period.
  Stripes.likelyPeriod(ColorScheme colors)
    : this(colors.error.withValues(alpha: 0.2));

  final Color color;

  static const _gap = 12.0;

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
        item(
          BoxDecoration(color: likelyPeriodFill(colors)),
          'Likely next period',
          stripes: Stripes.likelyPeriod(colors),
        ),
        item(BoxDecoration(color: colors.tertiaryContainer), 'Likely fertile'),
      ],
    );
  }
}
