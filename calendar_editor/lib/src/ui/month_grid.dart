import 'package:flutter/material.dart';

import 'days.dart';

/// How one day of a month grid shows: whether it is [marked] (e.g. has
/// events), [filled] (e.g. a period day), [hatched] (e.g. predicted) or
/// [tinted] (e.g. fertile).
typedef DayLook = ({int marked, bool filled, bool hatched, bool tinted});

/// A day that shows plain.
const DayLook plainDay = (
  marked: 0,
  filled: false,
  hatched: false,
  tinted: false,
);

/// The days of [month] that a month grid shows, whole weeks from the
/// locale's first weekday: from its first to the day after its last.
({DateTime first, DateTime end}) gridDays(DateTime month, int firstWeekday) {
  final start = DateTime(month.year, month.month);
  final lead = (start.weekday % 7 - firstWeekday) % 7;
  final first = DateTime(start.year, start.month, 1 - lead);
  final last = DateTime(month.year, month.month + 1, 0);
  final trail = (firstWeekday - (last.weekday % 7) - 1) % 7;
  return (
    first: first,
    end: DateTime(last.year, last.month, last.day + trail + 1),
  );
}

/// A month as a grid of days, whole weeks; each day looks as [lookOf]
/// says; tapping one picks it ([onPick]). [selected] and today stand out.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.lookOf,
    required this.onPick,
    super.key,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final DayLook Function(DateTime day) lookOf;
  final void Function(DateTime day) onPick;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final firstWeekday = words.firstDayOfWeekIndex;
    final (:first, :end) = gridDays(month, firstWeekday);
    final days = daysFrom(first, end);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final index in Iterable<int>.generate(7))
              Expanded(
                child: Center(
                  child: Text(
                    words.narrowWeekdays[(index + firstWeekday) % 7],
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        for (final week in Iterable<int>.generate(days.length ~/ 7))
          Row(
            children: [
              for (final day in days.skip(week * 7).take(7))
                Expanded(
                  child: _DayCell(
                    day,
                    look: lookOf(day),
                    inMonth: day.month == month.month,
                    selected: DateUtils.isSameDay(day, selected),
                    today: DateUtils.isSameDay(day, today),
                    onTap: () => onPick(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell(
    this.day, {
    required this.look,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final DateTime day;
  final DayLook look;
  final bool inMonth;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words = MaterialLocalizations.of(context);
    final text = Theme.of(context).textTheme.bodyMedium!;
    return Semantics(
      selected: selected,
      button: true,
      label: words.formatFullDate(day),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: switch (look) {
                (filled: true, hatched: _, marked: _, tinted: _) =>
                  colors.errorContainer,
                (tinted: true, filled: _, hatched: _, marked: _) =>
                  colors.tertiaryContainer,
                _ when selected => colors.secondaryContainer,
                _ => null,
              },
              borderRadius: BorderRadius.circular(8),
              border: switch ((look.hatched, today)) {
                (true, _) => Border.all(color: colors.error, width: 2),
                (false, true) => Border.all(color: colors.primary),
                _ => null,
              },
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: text.copyWith(
                    color: inMonth ? null : colors.outline,
                    fontWeight: today ? FontWeight.bold : null,
                  ),
                ),
                SizedBox(
                  height: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final _ in Iterable<int>.generate(
                        look.marked.clamp(0, 3),
                      ))
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A month's name and year with buttons to the month before and after.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    required this.month,
    required this.onMonth,
    this.trailing,
    super.key,
  });

  final DateTime month;
  final void Function(DateTime month) onMonth;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: 'Month before',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: Text(
            words.formatMonthYear(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Month after',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
        ),
        ?trailing,
      ],
    );
  }
}
