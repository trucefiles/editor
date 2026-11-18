import 'dart:async';

import 'package:truce_calendar/truce_calendar.dart' show Calendar;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart'
    show CalendarClock;
import 'package:truce_files/truce_files.dart';

import 'planner_role.dart';

/// The calendars shown on this device as one listing found them, for the
/// alerts: each with its version and calendar where it was read, and
/// whether the listing would show a file were it there.
typedef ShownCalendars = ({
  Map<FileKey, ListedCalendar> calendars,
  bool Function(FileKey key) sees,
});

/// [file] as the alerts plan from it, with its [calendar] if it was read.
ListedCalendar listedCalendar(ListedFile file, Calendar? calendar) =>
    (version: file.version.text, calendar: calendar);

/// The app's alerts for its run. Once the app holds the planner's role,
/// the planner starts and plans the calendars [show]n each time they
/// change, and again whenever the calendars' clock moves to a new day or
/// zone. While another part plans (Android's background check), the app
/// waits; asked to plan again, it lists the folders ([listFolders]) and
/// plans.
final class AppAlerts {
  AppAlerts({
    required this._planner,
    required this._clock,
    required this._role,
    required this._listFolders,
  });

  final AlertPlanner _planner;
  final CalendarClock _clock;
  final PlannerRole _role;
  final void Function() _listFolders;

  /// Whether it holds the role, and so plans.
  var _holds = false;
  var _ended = false;

  /// Whether the alerts are to be handed again once it holds the role.
  var _handAgainPending = false;
  ShownCalendars? _shown;

  /// Waits for the role, then starts the planner and plans.
  Future<void> start() async {
    _clock.addListener(_plan);
    await _role.take(onAsked: _planAgain);
    if (_ended) return _role.release();
    _holds = true;
    _planner.send(Started(now: _clock.now()));
    if (_handAgainPending) {
      _handAgainPending = false;
      handAgain();
    }
    _plan();
  }

  /// The calendars shown now.
  void show(ShownCalendars shown) {
    _shown = shown;
    _plan();
  }

  /// Hands every planned alert to the ringer again, e.g. as the way
  /// alerts ring changed; while another part plans, once it holds the
  /// role.
  void handAgain() {
    if (_holds) {
      _planner.send(HandAgain(now: _clock.now()));
    } else {
      _handAgainPending = true;
    }
  }

  /// The app may end now: completes once the planner kept that alerts up
  /// to now weren't missed. It goes on planning if the app goes on.
  Future<void> stopping() async {
    if (_holds) await _keepStop();
  }

  /// Stops planning for this run: alerts up to now weren't missed, and,
  /// once the planner kept that, the role is free for the background
  /// check.
  Future<void> stop() async {
    final held = _holds;
    _holds = false;
    if (held) await _keepStop();
    _role.release();
  }

  Future<void> _keepStop() {
    final now = _clock.now();
    return _planner.handle((ticket) => Stopping(now: now, ticket: ticket));
  }

  void dispose() {
    _ended = true;
    _clock.removeListener(_plan);
    unawaited(stop());
  }

  /// Another part asked to plan again: the folders are listed anew, and
  /// the calendars shown now are planned (a plan that needs no reads if
  /// nothing changed, but still moves on the days).
  void _planAgain() {
    _listFolders();
    _plan();
  }

  void _plan() {
    if (_shown case (:final calendars, :final sees)? when _holds) {
      _planner.send(
        CalendarsListed(
          now: _clock.now(),
          zone: _clock.zone,
          calendars: calendars,
          sees: sees,
        ),
      );
    }
  }
}
