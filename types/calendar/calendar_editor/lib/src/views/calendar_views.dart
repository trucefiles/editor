import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'calendar_views_model.dart';
import 'day_cells.dart';
import 'event_tiles.dart';
import 'insights_strip.dart';
import 'new_event_spot.dart';
import 'occurrence_event.dart';
import 'views_bar.dart';

/// What the user does with an occurrence of the calendar keyed [calendar].
typedef OnOccurrence<K> = void Function(K calendar, Occurrence occurrence);

/// Where the user dragged an occurrence: to [start] up to [end].
typedef OnMove<K> = void Function(
  K calendar,
  Occurrence occurrence,
  DateTime start,
  DateTime end,
);

/// [calendars] (by key) in a month, week, day or schedule view, each in
/// its color ([colorOf]; an event's own color or health kind comes
/// first), what they tell above (the insights strip, each named by
/// [titleOf] if given and several tell), the month's days shaded (weekends, health
/// calendars' cycle days); the user picks the view ([onKind] tells it, to
/// keep), pages through time and taps an occurrence ([onTap]). Only with
/// [onAdd] can the user add: by a tap on a free time or day, or a drag
/// over free times or days; [onAddDay] is told the day an Add button
/// starts on. Only with [onMove] can the user drag an occurrence or its
/// edge.
class CalendarViews<K> extends StatefulWidget {
  const CalendarViews({
    required this.calendars,
    required this.colorOf,
    required this.kind,
    required this.onKind,
    required this.now,
    this.titleOf,
    this.onTap,
    this.onAdd,
    this.onAddDay,
    this.onMove,
    super.key,
  });

  final Map<K, Calendar> calendars;
  final Color Function(K calendar) colorOf;

  /// The view it starts in.
  final CalendarViewKind kind;
  final ValueChanged<CalendarViewKind> onKind;

  /// The time now; today shows from it.
  final DateTime Function() now;

  /// A calendar's title, to name it above the views; `null` when only one
  /// shows.
  final String Function(K calendar)? titleOf;
  final OnOccurrence<K>? onTap;
  final ValueChanged<NewEventSpot>? onAdd;

  /// Told the day an Add button starts on as it changes: today if it
  /// shows, else the first day shown.
  final ValueChanged<DateTime>? onAddDay;
  final OnMove<K>? onMove;

  @override
  State<CalendarViews<K>> createState() => _CalendarViewsState<K>();
}

class _CalendarViewsState<K> extends State<CalendarViews<K>> {
  late final _model = CalendarViewsModel<K>(
    kind: widget.kind,
    calendars: widget.calendars,
    now: widget.now,
  );
  final _events = DefaultEventsController();
  KalenderController? _kalender;
  int? _firstDay;
  late Map<CalendarViewKind, ViewConfiguration> _configurations;
  // The current widget's colors: a calendar's color can change.
  late final _tiles = eventTiles<K>(_colorOf);
  late final _scheduleTiles = scheduleTiles<K>(_colorOf);

  Color _colorOf(K calendar) => widget.colorOf(calendar);

  @override
  void initState() {
    super.initState();
    _model.addListener(_showModel);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final firstDay = index == 0 ? DateTime.sunday : index;
    if (firstDay == _firstDay) return;
    _firstDay = firstDay;
    _configurations = configurationsFor(
      firstDayOfWeek: firstDay,
      now: widget.now,
    );
    final configuration = _configurations[_model.kind]!;
    switch (_kalender) {
      case final kalender?:
        kalender.viewConfiguration = configuration;
      case null:
        _kalender = KalenderController(viewConfiguration: configuration)
          ..visibleDateTimeRange.addListener(_showRange);
        _showRange();
    }
  }

  @override
  void didUpdateWidget(CalendarViews<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model.showCalendars(widget.calendars);
  }

  @override
  void dispose() {
    _model
      ..removeListener(_showModel)
      ..dispose();
    _kalender?.dispose();
    _events.dispose();
    super.dispose();
  }

  void _showRange() {
    final range = _kalender!.visibleDateTimeRange.value;
    _model.showRange(range.start, range.end);
  }

  /// Hands the model's state to kalender, which only shows it (today
  /// too, on the rebuild).
  void _showModel() {
    final kalender = _kalender!;
    final configuration = _configurations[_model.kind]!;
    if (kalender.viewConfiguration != configuration) {
      kalender.viewConfiguration = configuration;
    }
    _events.replaceEvents(eventsOf(_model.shown));
    widget.onAddDay?.call(_model.dayToAdd);
    setState(() {});
  }

  void _pickKind(CalendarViewKind kind) {
    _model.showKind(kind);
    widget.onKind(kind);
  }

  @override
  Widget build(BuildContext context) {
    final kalender = _kalender!;
    final onAdd = widget.onAdd;
    final onTap = widget.onTap;
    final onMove = widget.onMove;
    final movable = onMove != null;
    final callbacks = KalenderCallbacks(
      onEventTapped: onTap == null
          ? null
          : (event) {
              final shown = event as OccurrenceEvent<K>;
              onTap(shown.calendar, shown.occurrence);
            },
      onTappedWithDetail: onAdd == null
          ? null
          : (detail) => switch (detail) {
              DayDetail(:final date) => onAdd(
                AtTimes(date, date.add(const Duration(hours: 1))),
              ),
              MultiDayDetail(:final dateTimeRange) => onAdd(
                OnDay(dateTimeRange.start),
              ),
              _ => null,
            },
      onEventCreated: onAdd == null
          ? null
          : (event) => onAdd(
              NewEventSpot.of(event.start.toLocal(), event.end.toLocal()),
            ),
      onEventChanged: onMove == null
          ? null
          : (before, after) {
              // kalender reports a drop in place too.
              if (before.start == after.start && before.end == after.end) {
                return;
              }
              final shown = before as OccurrenceEvent<K>;
              onMove(
                shown.calendar,
                shown.occurrence,
                after.start.toLocal(),
                after.end.toLocal(),
              );
            },
    );
    return Column(
      children: [
        ViewsBar(
          title: _titleOf(context),
          kind: _model.kind,
          onKind: _pickKind,
          onPrevious: kalender.animateToPreviousPage,
          onNext: kalender.animateToNextPage,
          onToday: () => kalender.animateToDate(widget.now()),
        ),
        InsightsStrip<K>(
          health: _model.health,
          today: _model.today,
          titleOf: widget.titleOf,
        ),
        Expanded(
          child: KalenderView(
            eventsController: _events,
            kalenderController: kalender,
            locale: Localizations.localeOf(context),
            callbacks: callbacks,
            components: KalenderComponents(
              monthComponents: MonthComponents(
                bodyComponents: MonthBodyComponents(
                  monthDayCellBuilder: dayCells(_model.health),
                ),
              ),
            ),
            interaction: KalenderInteraction(
              allowResizing: movable,
              allowRescheduling: movable,
              // A drag over free times asks for a new event there.
              allowEventCreation: onAdd != null,
            ),
            views: [
              MultiDayViewParts(
                header: MultiDayHeader(tileComponents: _tiles),
                body: MultiDayBody(
                  tileComponents: _tiles,
                  snapping: const KalenderSnapping(snapIntervalMinutes: 15),
                ),
              ),
              MonthViewParts(body: MonthBody(tileComponents: _tiles)),
              ScheduleViewParts(
                body: ScheduleBody(tileComponents: _scheduleTiles),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// What the bar says is shown: the day in the day view, else the month
  /// most of the range lies in.
  String _titleOf(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final (range, middle) = (_model.range, _model.middle);
    if (range == null || middle == null) return '';
    return switch (_model.kind) {
      CalendarViewKind.day => words.formatMediumDate(range.from),
      _ => words.formatMonthYear(middle),
    };
  }
}

/// The kalender view of each kind, for weeks that start on
/// [firstDayOfWeek] (`DateTime.monday` and on), today from [now]; each
/// pages over two hundred years and opens on today when it shows.
Map<CalendarViewKind, ViewConfiguration> configurationsFor({
  required int firstDayOfWeek,
  required DateTime Function() now,
}) {
  final range = KalenderDateTimeRange(
    start: DateTime(1900),
    end: DateTime(2100),
  );
  const morning = KalenderTime(hour: 8, minute: 0);
  final today = now();
  // A new view opens on today where the old one showed it, else on the
  // old one's first day.
  FloatingDateTime focus(ViewTransitionContext transition) {
    final shown = transition.oldViewController.floatingVisibleRange.value;
    final day = FloatingDateTime.fromExternal(now());
    return day.isBefore(shown.start) || !day.isBefore(shown.end)
        ? kCarryFocusDate(transition)
        : day;
  }

  return {
    CalendarViewKind.month: MonthViewConfiguration.singleMonth(
      initialDateTime: today,
      dateResolver: focus,
      nowCallback: now,
      displayRange: range,
      firstDayOfWeek: firstDayOfWeek,
    ),
    CalendarViewKind.week: MultiDayViewConfiguration.week(
      initialDateTime: today,
      dateResolver: focus,
      nowCallback: now,
      displayRange: range,
      firstDayOfWeek: firstDayOfWeek,
      initialTimeOfDay: morning,
    ),
    CalendarViewKind.day: MultiDayViewConfiguration.singleDay(
      initialDateTime: today,
      dateResolver: focus,
      nowCallback: now,
      displayRange: range,
      firstDayOfWeek: firstDayOfWeek,
      initialTimeOfDay: morning,
    ),
    CalendarViewKind.schedule: ScheduleViewConfiguration.paginated(
      initialDateTime: today,
      dateResolver: focus,
      nowCallback: now,
      displayRange: range,
    ),
  };
}
