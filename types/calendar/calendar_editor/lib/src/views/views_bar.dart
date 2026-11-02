import 'package:flutter/material.dart';

import 'calendar_view_kind.dart';

/// The bar above the calendar views: the previous and next page, back to
/// today, what is shown ([title]), which view, and Add event if [onAdd]
/// is given.
class ViewsBar extends StatelessWidget {
  const ViewsBar({
    required this.title,
    required this.kind,
    required this.onKind,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.onAdd,
    super.key,
  });

  final String title;
  final CalendarViewKind kind;
  final ValueChanged<CalendarViewKind> onKind;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => IconButtonTheme(
    data: const IconButtonThemeData(
      style: ButtonStyle(visualDensity: VisualDensity.compact),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous',
          onPressed: onPrevious,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next',
          onPressed: onNext,
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.today_outlined),
          tooltip: 'Today',
          onPressed: onToday,
        ),
        PopupMenuButton<CalendarViewKind>(
          tooltip: 'Pick a view',
          initialValue: kind,
          onSelected: onKind,
          itemBuilder: (context) => [
            for (final each in CalendarViewKind.values)
              PopupMenuItem(
                value: each,
                child: ListTile(
                  leading: Icon(_iconOf(each)),
                  title: Text(_labelOf(each)),
                ),
              ),
          ],
          // The view's icon only, so the bar fits a phone at large text.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconOf(kind)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (onAdd case final onAdd?)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add event',
            onPressed: onAdd,
          ),
      ],
    ),
  );
}

String _labelOf(CalendarViewKind kind) => switch (kind) {
  CalendarViewKind.month => 'Month',
  CalendarViewKind.week => 'Week',
  CalendarViewKind.day => 'Day',
  CalendarViewKind.schedule => 'Schedule',
};

IconData _iconOf(CalendarViewKind kind) => switch (kind) {
  CalendarViewKind.month => Icons.calendar_view_month,
  CalendarViewKind.week => Icons.calendar_view_week,
  CalendarViewKind.day => Icons.calendar_view_day,
  CalendarViewKind.schedule => Icons.view_agenda_outlined,
};
