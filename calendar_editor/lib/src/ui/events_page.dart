import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../device_zone.dart';
import 'days.dart';
import 'event_actions.dart';
import 'month_grid.dart';
import 'occurrence_texts.dart';

/// A calendar as a month grid and the picked day's events: tap a day to
/// see it, an event to edit or delete it, Add event to add one there.
/// Only to read unless [edit] is given.
class EventsPage extends StatefulWidget {
  const EventsPage(
    this.calendar, {
    this.edit,
    required this.today,
    required this.deviceZone,
    super.key,
  });

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime today;
  final DeviceZone deviceZone;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late var _month = DateTime(widget.today.year, widget.today.month);
  late var _day = DateUtils.dateOnly(widget.today);

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final (:first, :end) = gridDays(_month, words.firstDayOfWeekIndex);
    final counts = countsByDay(occurrences(widget.calendar, first, end));
    final ofDay = occurrences(widget.calendar, _day, nextDay(_day));
    final edit = widget.edit;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        MonthHeader(
          month: _month,
          onMonth: (month) => setState(() => _month = month),
        ),
        MonthGrid(
          month: _month,
          selected: _day,
          today: widget.today,
          lookOf: (day) => (
            marked: counts[day] ?? 0,
            filled: false,
            hatched: false,
            tinted: false,
          ),
          onPick: (day) => setState(() {
            _day = day;
            _month = DateTime(day.year, day.month);
          }),
        ),
        const Divider(),
        ListTile(
          title: Text(
            words.formatFullDate(_day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: edit == null
              ? null
              : FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add event'),
                  onPressed: () =>
                      addEvent(context, _day, edit, widget.deviceZone),
                ),
        ),
        if (ofDay.isEmpty)
          const ListTile(title: Text('Nothing on this day.'))
        else
          for (final occurrence in ofDay)
            ListTile(
              leading: Icon(
                occurrence.recurrence == null ? Icons.event : Icons.repeat,
              ),
              title: Text(occurrenceTitle(occurrence)),
              subtitle: Text(
                [
                  timesOf(
                    words,
                    occurrence,
                    use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
                  ),
                  if (occurrence.part.location.isNotEmpty)
                    occurrence.part.location,
                ].join(' · '),
              ),
              onTap: edit == null
                  ? null
                  : () => showOccurrenceActions(
                      context,
                      occurrence,
                      edit,
                      widget.deviceZone,
                    ),
            ),
      ],
    );
  }
}
