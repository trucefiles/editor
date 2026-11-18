import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart'
    show CalendarClock;
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/alerts/app_alerts.dart';
import 'package:truce_editor/alerts/planner_role.dart';
import 'package:truce_files/truce_files.dart';

import 'quiet_alerts.dart';

/// A store in memory; it keeps a value once [saving] lets it.
final class _Store implements SettingStore<RingState> {
  RingState kept = RingState.none;
  Completer<void>? saving;

  @override
  Future<RingState> load() async => kept;

  @override
  Future<void> save(RingState value) async {
    await saving?.future;
    kept = value;
  }
}

/// A role another part holds until [free] completes.
final class _HeldRole implements PlannerRole {
  final free = Completer<void>();
  var released = 0;

  @override
  Future<void> take({required void Function() onAsked}) => free.future;

  @override
  Future<bool> takeOrAsk() async => false;

  @override
  void release() => released++;
}

/// A role that is free, and keeps how to ask its holder to plan again.
final class _AskedRole implements PlannerRole {
  late void Function() ask;

  @override
  Future<void> take({required void Function() onAsked}) async => ask = onAsked;

  @override
  Future<bool> takeOrAsk() async => false;

  @override
  void release() {}
}

final FileKey _work = (
  folder: const FolderId('fake', 'a'),
  path: RelPath.parse('work.ics')!,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = DateTime(2026, 11, 17, 8);
  late DateTime now;
  late QuietRinger ringer;
  late _Store store;
  late AlertPlanner planner;
  late CalendarClock clock;

  setUp(() {
    now = start;
    ringer = QuietRinger();
    store = _Store();
    planner = AlertPlanner(ringer: ringer, store: store);
    clock = CalendarClock(() => now, deviceZone: () => 'UTC');
    addTearDown(clock.dispose);
  });

  var listings = 0;
  AppAlerts alertsWith(PlannerRole role) => AppAlerts(
    planner: planner,
    clock: clock,
    role: role,
    listFolders: () => listings++,
  );

  final shown = (
    calendars: <FileKey, ListedCalendar>{
      _work: (
        version: '1',
        calendar: Calendar.read(
          'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:standup\n'
          'SUMMARY:Standup\nDTSTART:20261117T093000\nDURATION:PT15M\n'
          'BEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-PT15M\nEND:VALARM\n'
          'END:VEVENT\nEND:VCALENDAR\n',
        ),
      ),
    },
    sees: (FileKey _) => true,
  );

  test(
    'plans the shown calendars once it holds the role, not before',
    () async {
      final role = _HeldRole();
      final alerts = alertsWith(role);
      addTearDown(alerts.dispose);
      final started = alerts.start();
      alerts.show(shown);
      await pumpEventQueue();
      expect(planner.state.planned, isEmpty, reason: 'the role is held');

      role.free.complete();
      await started;
      await pumpEventQueue();
      expect(
        [for (final alert in planner.state.planned) alert.title],
        ['Standup'],
      );
    },
  );

  test('stopping tells the planner the app could ring until now, and frees '
      'the role', () async {
    final role = _HeldRole()..free.complete();
    final alerts = alertsWith(role);
    await alerts.start();
    alerts.show(shown);
    await pumpEventQueue();
    now = start.add(const Duration(hours: 2));

    await alerts.stop();

    expect(store.kept.lastAlive, start.add(const Duration(hours: 2)));
    expect(role.released, 1);
    alerts.dispose();
  });

  test('the role is freed only once the planner kept the stop', () async {
    final role = _HeldRole()..free.complete();
    final alerts = alertsWith(role);
    await alerts.start();
    alerts.show(shown);
    await pumpEventQueue();
    store.saving = Completer();
    now = start.add(const Duration(hours: 1));

    final stopped = alerts.stop();
    await pumpEventQueue();
    expect(role.released, 0, reason: 'the stop is not kept yet');

    store.saving!.complete();
    await stopped;
    expect(role.released, 1);
    alerts.dispose();
  });

  test('asked to plan again, it lists the folders and plans', () async {
    final role = _AskedRole();
    final alerts = alertsWith(role);
    addTearDown(alerts.dispose);
    await alerts.start();
    alerts.show(shown);
    await pumpEventQueue();
    // A day later, with nothing changed in the folders.
    now = start.add(const Duration(days: 1));
    listings = 0;

    role.ask();
    await pumpEventQueue();
    expect(listings, 1);
    expect(planner.state.ring.plans[_work]?.day, dayOf(now));
  });

  test('handing again rings the planned alerts again', () async {
    final alerts = alertsWith(const SoleRole());
    addTearDown(alerts.dispose);
    await alerts.start();
    alerts.show(shown);
    await pumpEventQueue();
    ringer.ringing.clear();

    alerts.handAgain();
    await pumpEventQueue();
    expect(ringer.ringing, hasLength(1));
  });

  test("the app may end: the planner keeps that alerts until now weren't "
      'missed, and it goes on planning', () async {
    final role = _HeldRole()..free.complete();
    final alerts = alertsWith(role);
    addTearDown(alerts.dispose);
    await alerts.start();
    alerts.show(shown);
    await pumpEventQueue();
    now = start.add(const Duration(hours: 1));

    await alerts.stopping();
    expect(store.kept.lastAlive, start.add(const Duration(hours: 1)));
    expect(role.released, 0);

    ringer.ringing.clear();
    alerts.handAgain();
    await pumpEventQueue();
    expect(ringer.ringing, hasLength(1), reason: 'it still plans');
  });

  test('a hand again asked while another part plans is sent once it holds '
      'the role', () async {
    final role = _HeldRole();
    final alerts = alertsWith(role);
    addTearDown(alerts.dispose);
    final started = alerts.start();
    alerts.show(shown);
    // The background check planned this alert before.
    await planner.handle((ticket) => Started(now: start, ticket: ticket));
    await planner.handle(
      (ticket) => CalendarsListed(
        now: start,
        zone: 'UTC',
        calendars: shown.calendars,
        sees: shown.sees,
        ticket: ticket,
      ),
    );
    ringer.ringing.clear();

    alerts.handAgain();
    role.free.complete();
    await started;
    await pumpEventQueue();
    expect(ringer.ringing, hasLength(1));
  });
}
