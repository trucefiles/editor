import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import '../day_clock.dart';
import 'cycle_text.dart';
import 'event_actions.dart';
import 'health_entry_form.dart';
import 'month_grid.dart';

/// A health calendar: a month grid with period days, the next period's
/// likely days (outlined) and the fertile window (tinted), a line on the
/// cycle, and the picked day's entries to add, edit or delete; today
/// from [now], moving on at midnight. Only to read unless [edit] is
/// given.
class HealthPage extends StatefulWidget {
  const HealthPage(this.calendar, {this.edit, required this.now, super.key});

  final Calendar calendar;
  final MakeEdit? edit;
  final DateTime Function() now;

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late final _clock = DayClock(widget.now)..addListener(_dayChanged);
  late var _month = DateTime(_today.year, _today.month);
  late var _day = _today;

  DateTime get _today => _clock.today;

  void _dayChanged() => setState(() {});

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final byDay = healthByDay(widget.calendar);
    final periods = {for (final day in periodDays(widget.calendar)) _key(day)};
    final cycle = predictCycle(periodDays(widget.calendar), _today);
    final predicted = {
      for (final day in cycle?.nextPeriod ?? <DateTime>[]) _key(day),
    };
    final fertile = {
      for (final day in cycle?.fertileWindow ?? <DateTime>[]) _key(day),
    };
    final entries = byDay[_key(_day)] ?? const <CalendarEvent>[];
    final edit = widget.edit;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        if (cycle != null) _CycleLine(cycle, today: _today),
        MonthHeader(
          month: _month,
          onMonth: (month) => setState(() => _month = month),
        ),
        MonthGrid(
          month: _month,
          selected: _day,
          today: _today,
          lookOf: (day) {
            final key = _key(day);
            return (
              marked:
                  (byDay[key]?.length ?? 0) - (periods.contains(key) ? 1 : 0),
              filled: periods.contains(key),
              hatched: !periods.contains(key) && predicted.contains(key),
              tinted: fertile.contains(key),
            );
          },
          onPick: (day) => setState(() {
            _day = day;
            _month = DateTime(day.year, day.month);
          }),
        ),
        const _Legend(),
        const Divider(),
        ListTile(
          title: Text(
            words.formatFullDate(_day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: edit == null
              ? null
              : PopupMenuButton<HealthEntry>(
                  tooltip: 'Add entry',
                  icon: const Icon(Icons.add),
                  itemBuilder: (_) => [
                    for (final (label, entry) in healthKinds)
                      PopupMenuItem(value: entry, child: Text(label)),
                  ],
                  onSelected: (entry) => _add(context, entry, edit),
                ),
        ),
        if (entries.isEmpty)
          const ListTile(title: Text('Nothing written on this day.'))
        else
          for (final event in entries)
            ListTile(
              title: Text(event.series.summary),
              subtitle: event.series.description.isEmpty
                  ? null
                  : Text(event.series.description),
              onTap: edit == null ? null : () => _change(context, event, edit),
            ),
      ],
    );
  }

  /// A day as the health days are keyed: its UTC midnight.
  static DateTime _key(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day);

  Future<void> _add(
    BuildContext context,
    HealthEntry entry,
    MakeEdit edit,
  ) async {
    final made = await showHealthEntryForm(context, entry, title: 'New entry');
    if (made == null) return;
    final uid = newUid();
    final day = _key(_day);
    edit(
      (at) => AddEvent(
        uid,
        EventDraft.health(made.entry, day, note: made.note),
        at: at,
      ),
    );
  }

  Future<void> _change(
    BuildContext context,
    CalendarEvent event,
    MakeEdit edit,
  ) async {
    final part = event.series;
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (delete == null || !context.mounted) return;
    if (delete) return edit((at) => DeleteEvent(event.uid, at: at));
    final made = await showHealthEntryForm(
      context,
      part.health!,
      note: part.description,
      title: 'Edit entry',
    );
    if (made == null) return;
    final day = part.start!.wall;
    edit(
      (at) => ChangeSeries(
        event.uid,
        EventDraft.health(made.entry, day, note: made.note),
        at: at,
      ),
    );
  }
}

/// Where the cycle is today, and that it is only a guess.
class _CycleLine extends StatelessWidget {
  const _CycleLine(this.cycle, {required this.today});

  final CyclePrediction cycle;
  final DateTime today;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.water_drop_outlined),
    title: Text(cycleText(cycle, today)),
    subtitle: const Text(
      'An estimate from your entries, not for contraception.',
    ),
  );
}

/// What the marks in the grid mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    Widget item(BoxDecoration look, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: look),
        const SizedBox(width: 4),
        Text(text, style: small),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          item(BoxDecoration(color: colors.errorContainer), 'Period'),
          item(
            BoxDecoration(border: Border.all(color: colors.error, width: 2)),
            'Likely next period',
          ),
          item(
            BoxDecoration(color: colors.tertiaryContainer),
            'Likely fertile',
          ),
        ],
      ),
    );
  }
}
