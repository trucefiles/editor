import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import 'calendar_views_model.dart';
import 'day_cells.dart';
import 'event_tiles.dart';
import 'insights_strip.dart';
import 'month_picker.dart';
import 'new_event_spot.dart';
import 'occurrence_event.dart';
import 'occurrence_events.dart';
import 'page_mover.dart';
import 'sideways_wheel.dart';
import 'stripes.dart';
import 'views_bar.dart';
import 'week_day_names.dart';

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
/// first), what they tell below (the insights strip, each named by
/// [titleOf] if given and several tell), the month's days shaded (weekends, health
/// calendars' cycle days); the user picks the view ([onKind] tells it, to
/// keep), pages through time (with the bar's buttons, a swipe, or Shift
/// and the mouse wheel), goes to a date picked from the bar's title (a
/// month in the month and schedule views) or to a day's own view by a
/// tap on its date (a pick of the day view, told [onKind] too), and taps
/// an occurrence ([onTap]). Only with
/// [onAdd] is the user asking to add told, by a tap on a free time or
/// day, or a drag over free times or days; the host decides what
/// follows. [onAddDay] is told the day an Add button starts on. Only
/// with [onMove] can the user drag an occurrence or its edge; without
/// it, faint stripes behind the views say they can't be edited here.
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
  late final _events = OccurrenceEvents<K>(widget.calendars);
  KalenderController? _kalender;
  int? _firstDay;
  late Map<CalendarViewKind, ViewConfiguration> _configurations;
  late final _pages = PageMover(
    pages: () => _pagesOf(_configurations[_model.kind]!),
    shown: () => _model.middle ?? _model.today,
    animateTo: (date) => _kalender!.animateToDate(date),
    jumpTo: (date) => _kalender!.jumpToDate(date),
  );
  // The current widget's colors: a calendar's color can change.
  late final _timedTiles = eventTiles<K>(_colorOf, lines: 3);
  // Month days and the all-day row are one tile high.
  late final _rowTiles = eventTiles<K>(_colorOf, lines: 1);
  late final _scheduleTiles = scheduleTiles<K>(_colorOf);

  Color _colorOf(K calendar) => widget.colorOf(calendar);

  @override
  void initState() {
    super.initState();
    _model.addListener(_showModel);
    _model.range.addListener(_tellAddDay);
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
    _events.showCalendars(widget.calendars);
  }

  @override
  void dispose() {
    _model.range.removeListener(_tellAddDay);
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
  /// too, on the rebuild). Paging doesn't reach here: kalender pages on
  /// its own and asks for its events.
  void _showModel() {
    final kalender = _kalender!;
    final configuration = _configurations[_model.kind]!;
    if (kalender.viewConfiguration != configuration) {
      kalender.viewConfiguration = configuration;
    }
    _tellAddDay();
    setState(() {});
  }

  void _tellAddDay() => widget.onAddDay?.call(_model.dayToAdd);

  void _pickKind(CalendarViewKind kind) {
    _model.showKind(kind);
    widget.onKind(kind);
  }

  /// Shows [date]'s day in the day view, moving from the day it opens on
  /// once it shows.
  Future<void> _showDay(DateTime date) async {
    _pickKind(CalendarViewKind.day);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _pages.to(DateUtils.dateOnly(date));
  }

  /// Asks for a date to go to, starting on today if it shows, else on
  /// the first day shown: a month in the month and schedule views, else
  /// a day; shows it in the view shown.
  Future<void> _goTo() async {
    final shown = _model.dayToAdd;
    final picked = await switch (_model.kind) {
      CalendarViewKind.month || CalendarViewKind.schedule => pickMonth(
        context,
        shown: shown,
        today: _model.today,
        first: _shownDays.from,
        last: _shownDays.last,
      ),
      CalendarViewKind.week || CalendarViewKind.day => showDatePicker(
        context: context,
        initialDate: shown,
        currentDate: _model.today,
        firstDate: _shownDays.from,
        lastDate: _shownDays.last,
      ),
    };
    if (picked != null && mounted) await _pages.to(picked);
  }

  @override
  Widget build(BuildContext context) {
    final kalender = _kalender!;
    final onAdd = widget.onAdd;
    final onTap = widget.onTap;
    final onMove = widget.onMove;
    final movable = onMove != null;
    final callbacks = KalenderCallbacks(
      dateLabel: GestureCallbacks(
        onTap: (detail) => unawaited(_showDay(detail.date)),
      ),
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
        // Only the bar follows the range: a page change rebuilds no page.
        ValueListenableBuilder(
          valueListenable: _model.range,
          builder: (context, _, _) => ViewsBar(
            title: _titleOf(context),
            kind: _model.kind,
            onKind: _pickKind,
            onPrevious: () => unawaited(_pages.step(-1)),
            onNext: () => unawaited(_pages.step(1)),
            onToday: () => unawaited(_pages.to(widget.now())),
            onTitle: () => unawaited(_goTo()),
          ),
        ),
        Expanded(
          child: EscCloses(
            open: kalender.openDayOverlay,
            close: kalender.hideDayOverlay,
            child: SidewaysWheel(
              onPrevious: () => _pages.step(-1),
              onNext: () => _pages.step(1),
              child: CustomPaint(
                painter: movable
                    ? null
                    : Stripes.readOnly(Theme.of(context).colorScheme),
                // Its own layer, so scrolling and paging never repaint the
                // stripes behind it.
                child: RepaintBoundary(
                  child: KalenderView(
                    eventsController: _events,
                    kalenderController: kalender,
                    locale: Localizations.localeOf(context),
                    callbacks: callbacks,
                    components: KalenderComponents(
                      monthComponents: MonthComponents(
                        headerComponents: monthHeaderNames,
                        bodyComponents: MonthBodyComponents(
                          monthDayCellBuilder: dayCells(_model.health),
                          monthDayHeaderBuilder: dayNumber,
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
                        header: MultiDayHeader(tileComponents: _rowTiles),
                        body: MultiDayBody(
                          tileComponents: _timedTiles,
                          // Not to the current time: it would carry its minutes
                          // and seconds into the event.
                          snapping: const KalenderSnapping(
                            snapIntervalMinutes: 15,
                            snapToTimeIndicator: false,
                          ),
                        ),
                      ),
                      MonthViewParts(
                        body: MonthBody(tileComponents: _rowTiles),
                      ),
                      ScheduleViewParts(
                        body: ScheduleBody(tileComponents: _scheduleTiles),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        InsightsStrip<K>(
          health: _model.health,
          today: _model.today,
          titleOf: widget.titleOf,
        ),
      ],
    );
  }

  /// What the bar says is shown: the day in the day view, else the month
  /// most of the range lies in.
  String _titleOf(BuildContext context) {
    final words = MaterialLocalizations.of(context);
    final (range, middle) = (_model.range.value, _model.middle);
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
    start: _shownDays.from,
    end: _shownDays.to,
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

/// The days the views page over: two hundred years, [to] not included,
/// so [last] is the last.
final _shownDays = (
  from: DateTime(1900),
  to: DateTime(2100),
  last: DateTime(2099, 12, 31),
);

/// The pages of a view [configuration] of [configurationsFor].
PageIndexCalculator _pagesOf(ViewConfiguration configuration) =>
    switch (configuration) {
      MonthViewConfiguration(:final PageIndexCalculator pageIndexCalculator) ||
      MultiDayViewConfiguration(:final pageIndexCalculator) ||
      ScheduleViewConfiguration(
        :final pageIndexCalculator,
      ) => pageIndexCalculator,
      _ => throw UnsupportedError('No pages in $configuration'),
    };
