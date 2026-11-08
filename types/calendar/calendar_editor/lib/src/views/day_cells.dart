import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

import 'health_days.dart';
import 'stripes.dart';

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

/// A day's number in the month view, made smaller where its cell is too
/// narrow for it (very large text), never broken over two lines. Each is
/// laid out as wide as kalender lays out a two-digit number, so all
/// shrink alike and show at one size.
Widget dayNumber(BuildContext context, DateTime date) => FittedBox(
  fit: BoxFit.scaleDown,
  child: SizedBox(
    width: _twoDigitsWidth(context),
    child: Center(child: MonthDayHeader(date: date)),
  ),
);

/// How wide kalender lays out a two-digit day number in [context], from
/// the same inputs as its `MonthDayHeader`: the theme's button size if
/// set, else its text in the theme's number style with the button's
/// padding (Material's default 8 on each side), at least the button's
/// smallest width ([_smallestButton]); and the theme's margin around it.
/// Worked out from the text, as a hidden two-digit number in each cell
/// cost as much as the numbers shown.
double _twoDigitsWidth(BuildContext context) {
  final header = KalenderTheme.of(context).monthDayHeaderStyle;
  final margin = header?.margin?.horizontal ?? 0;
  if (header?.buttonSize case final size?) return size.width + margin;
  final painter = TextPainter(
    text: TextSpan(
      text: '30',
      style: DefaultTextStyle.of(context).style.merge(header?.numberTextStyle),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final text = painter.width;
  painter.dispose();
  return max(text + 2 * 8, _smallestButton(context)) + margin;
}

/// The narrowest kalender's day number button gets in [context]: Material
/// 3's icon button minimum (40), or the tap target (48) where taps get
/// padded targets (touch), each at the button's compact density.
double _smallestButton(BuildContext context) {
  final tapTarget = switch (Theme.of(context).materialTapTargetSize) {
    MaterialTapTargetSize.padded => kMinInteractiveDimension,
    MaterialTapTargetSize.shrinkWrap => 0.0,
  };
  return max(40.0, tapTarget) + VisualDensity.compact.baseSizeAdjustment.dx;
}

/// The fill of a day likely in a period: paler than a known period day,
/// so it reads as likely; pink on dark, where the theme's red looks rose.
Color likelyPeriodFill(ColorScheme colors) =>
    Color.alphaBlend(switch (colors.brightness) {
      Brightness.light => colors.errorContainer.withValues(alpha: 0.3),
      Brightness.dark => const Color(0xFFF48FB1).withValues(alpha: 0.6),
    }, colors.surface);

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
