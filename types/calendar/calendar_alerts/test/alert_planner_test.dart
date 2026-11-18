import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// A ringer that keeps what it was told.
final class _Ringer implements Ringer {
  _Ringer({this.ringsWhileClosed = true});

  @override
  final bool ringsWhileClosed;

  @override
  Stream<DateTime> get rang => const Stream.empty();

  /// What it rings now, by number.
  final ringing = <int, PlannedAlert>{};
  final told = <List<RingChange>>[];
  final missed = <PlannedAlert>[];

  @override
  Future<void> apply(List<RingChange> changes) async {
    told.add(changes);
    for (final change in changes) {
      switch (change) {
        case Ring(:final number, :final alert):
          ringing[number] = alert;
        case Silence(:final number):
          ringing.remove(number);
      }
    }
  }

  @override
  Future<void> showMissed(List<PlannedAlert> missed) async =>
      this.missed.addAll(missed);

  List<String> get titles =>
      [for (final alert in ringing.values) alert.title]..sort();
}

/// A store in memory that keeps its value as JSON, as the app's does.
final class _Store implements SettingStore<RingState> {
  Object? json;
  var saves = 0;

  @override
  Future<RingState> load() async => RingState.fromJson(json);

  @override
  Future<void> save(RingState value) async {
    saves++;
    json = value.toJson();
  }
}

final FileKey _work = (
  folder: const FolderId('fake', 'a'),
  path: RelPath.parse('work.ics')!,
);
final FileKey _home = (
  folder: const FolderId('fake', 'a'),
  path: RelPath.parse('home.ics')!,
);

/// A calendar of events titled as [events] say, each starting at its
/// time on this device's clock, with an alert 15 minutes before.
Calendar _calendar(Map<String, DateTime> events) => Calendar.read(
  'BEGIN:VCALENDAR\nVERSION:2.0\n'
  '${[for (final MapEntry(key: title, value: start) in events.entries) _event(title, start)].join()}'
  'END:VCALENDAR\n',
)!;

String _event(String title, DateTime start) {
  String two(int n) => n.toString().padLeft(2, '0');
  final at =
      '${start.year}${two(start.month)}${two(start.day)}'
      'T${two(start.hour)}${two(start.minute)}00';
  return 'BEGIN:VEVENT\nUID:$title\nSUMMARY:$title\nDTSTART:$at\n'
      'DURATION:PT1H\nBEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-PT15M\n'
      'END:VALARM\nEND:VEVENT\n';
}

final _monday = DateTime(2026, 11, 16, 8);

/// A file's version as text, for a file changed at [time].
String _versionOf(DateTime time) => time.toIso8601String();
const _zone = 'Europe/Berlin';

void main() {
  late _Ringer ringer;
  late _Store store;
  late AlertPlanner planner;

  setUp(() {
    ringer = _Ringer();
    store = _Store();
    planner = AlertPlanner(ringer: ringer, store: store);
  });

  Future<void> list(
    Map<FileKey, Calendar?> calendars, {
    DateTime? now,
    String zone = _zone,
    DateTime? version,
    bool Function(FileKey file)? sees,
  }) => planner.handle(
    (ticket) => CalendarsListed(
      now: now ?? _monday,
      zone: zone,
      calendars: {
        for (final MapEntry(key: file, value: calendar) in calendars.entries)
          file: (version: _versionOf(version ?? _monday), calendar: calendar),
      },
      sees: sees ?? (_) => true,
      ticket: ticket,
    ),
  );

  Future<void> start({DateTime? now}) =>
      planner.handle((ticket) => Started(now: now ?? _monday, ticket: ticket));

  test('plans the alerts of the next seven days', () async {
    await start();
    await list({
      _work: _calendar({
        'today': _monday.add(const Duration(hours: 2)),
        'in six days': _monday.add(const Duration(days: 6)),
        'in eight days': _monday.add(const Duration(days: 8)),
        'past': _monday.subtract(const Duration(hours: 2)),
      }),
    });
    expect(ringer.titles, ['in six days', 'today']);
    expect(planner.state.planned, hasLength(2));
  });

  test('a changed calendar is planned anew alone; an unchanged one tells '
      'the ringer nothing', () async {
    final work = _calendar({'meeting': _monday.add(const Duration(hours: 3))});
    await start();
    await list({
      _work: work,
      _home: _calendar({'dinner': _monday.add(const Duration(hours: 10))}),
    });
    ringer.told.clear();
    await list({
      _work: work,
      _home: _calendar({'dinner': _monday.add(const Duration(hours: 10))}),
    });
    expect(ringer.told, isEmpty);
    await planner.handle(
      (ticket) => CalendarsListed(
        now: _monday,
        zone: _zone,
        calendars: {
          _work: (
            version: _versionOf(_monday.add(const Duration(minutes: 1))),
            calendar: _calendar({
              'meeting': _monday.add(const Duration(hours: 4)),
            }),
          ),
          // Not read: unchanged.
          _home: (version: _versionOf(_monday), calendar: null),
        },
        sees: (_) => true,
        ticket: ticket,
      ),
    );
    expect(ringer.titles, ['dinner', 'meeting']);
    expect(
      [
        for (final change in ringer.told.single)
          (change.runtimeType, change.number),
      ],
      [(Ring, 1)],
    );
  });

  test('a kept alert keeps its number when its title changes', () async {
    await start();
    final at = _monday.add(const Duration(hours: 3));
    await list({
      _work: _calendar({'call': at}),
    });
    final number = ringer.ringing.keys.single;
    await list({
      _work: Calendar.read(
        _calendar({'call': at}).text
            .replaceFirst('SUMMARY:call', 'SUMMARY:Call Ann'),
      )!,
    }, version: _monday.add(const Duration(minutes: 1)));
    expect(ringer.ringing.keys.single, number);
    expect(ringer.ringing[number]!.title, 'Call Ann');
  });

  test('the days move on: the next day plans one more day', () async {
    final work = _calendar({
      'in seven and a half days': _monday.add(
        const Duration(days: 7, hours: 12),
      ),
    });
    await start();
    await list({_work: work});
    expect(ringer.titles, isEmpty);
    await list({_work: work}, now: _monday.add(const Duration(days: 1)));
    expect(ringer.titles, ['in seven and a half days']);
  });

  test('a new time zone plans all anew', () async {
    await start();
    final work = _calendar({'meeting': _monday.add(const Duration(hours: 3))});
    await list({_work: work});
    final before = planner.state.ring;
    expect(
      before.needsRead(_work, _versionOf(_monday), now: _monday, zone: _zone),
      isFalse,
    );
    expect(
      before.needsRead(
        _work,
        _versionOf(_monday),
        now: _monday,
        zone: 'Asia/Tokyo',
      ),
      isTrue,
    );
  });

  test('a calendar that should have been read for a new day, but came '
      'without, is read at the next listing', () async {
    await start();
    // Eight days ahead: past this plan's seven.
    final work = _calendar({
      'review': _monday.add(const Duration(days: 7, hours: 2)),
    });
    await list({_work: work});
    expect(ringer.titles, isEmpty);
    final tuesday = _monday.add(const Duration(days: 1));
    await list({_work: null}, now: tuesday);
    await list({_work: work}, now: tuesday);
    expect(ringer.titles, ['review']);
  });

  test('a listing that changes nothing writes nothing', () async {
    await start();
    final work = _calendar({'meeting': _monday.add(const Duration(hours: 3))});
    await list({_work: work});
    final saves = store.saves;

    await list({_work: work}, now: _monday.add(const Duration(minutes: 20)));
    await planner.handle(
      (ticket) =>
          Rang(now: _monday.subtract(const Duration(hours: 1)), ticket: ticket),
    );
    expect(store.saves, saves);

    // Once the alert rang, the next listing drops it, and keeps that.
    await list({_work: work}, now: _monday.add(const Duration(hours: 4)));
    expect(store.saves, saves + 1);
    expect(planner.state.ring.lastAlive, _monday.add(const Duration(hours: 4)));
  });

  test('a calendar no longer listed is silenced', () async {
    await start();
    await list({
      _work: _calendar({'meeting': _monday.add(const Duration(hours: 3))}),
    });
    await list({});
    expect(ringer.ringing, isEmpty);
    expect(planner.state.ring.plans, isEmpty);
  });

  test("a calendar the listing couldn't see keeps its alerts", () async {
    await start();
    await list({
      _work: _calendar({'meeting': _monday.add(const Duration(hours: 3))}),
    });
    // Its folder couldn't be listed this time.
    await list({}, sees: (file) => file != _work);
    expect(ringer.titles, ['meeting']);
    expect(planner.state.ring.plans.keys, [_work]);
  });

  test('only the nearest are planned', () async {
    await start();
    await list({
      _work: _calendar({
        for (var i = 0; i < mostPlanned + 20; i++)
          'e$i': _monday.add(Duration(minutes: 30 + i * 30)),
      }),
    });
    expect(ringer.ringing, hasLength(mostPlanned));
    expect(ringer.titles, isNot(contains('e${mostPlanned + 19}')));
  });

  test('hand again rings each planned alert still to come again under its '
      'own number, taking none back', () async {
    await start();
    final work = _calendar({
      'standup': _monday.add(const Duration(minutes: 30)),
      'meeting': _monday.add(const Duration(hours: 3)),
    });
    await list({_work: work});
    final number = {
      for (final MapEntry(key: number, value: alert) in ringer.ringing.entries)
        alert.title: number,
    }['meeting'];
    ringer.told.clear();
    // The standup's alert rang at 8:15.
    await planner.handle(
      (ticket) => HandAgain(
        now: _monday.add(const Duration(minutes: 20)),
        ticket: ticket,
      ),
    );
    expect(
      [
        for (final change in ringer.told.single)
          (change.runtimeType, change.number),
      ],
      [(Ring, number)],
    );
  });

  test('an alert that came between the start and the first listing still '
      'rings', () async {
    ringer = _Ringer(ringsWhileClosed: false);
    planner = AlertPlanner(ringer: ringer, store: store);
    await start();
    // Reading the calendars took until 8:20; the alert came at 8:15.
    await list({
      _work: _calendar({'standup': _monday.add(const Duration(minutes: 30))}),
    }, now: _monday.add(const Duration(minutes: 20)));
    expect(ringer.titles, ['standup']);
    expect(ringer.missed, isEmpty);
  });

  group('missed', () {
    test('on a ringer that rings while closed: only ones it never held, '
        'while their event lasts', () async {
      await start();
      final work = _calendar({'held': _monday.add(const Duration(hours: 1))});
      await list({_work: work});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      // Meanwhile another device added two events; the ringer held the
      // first alert, which rang.
      planner = AlertPlanner(ringer: ringer, store: store);
      final later = _monday.add(const Duration(hours: 3));
      await start(now: later);
      await list(
        {
          _work: _calendar({
            'held': _monday.add(const Duration(hours: 1)),
            'added, still on': _monday.add(
              const Duration(hours: 2, minutes: 30),
            ),
            'added, over': _monday.add(const Duration(hours: 1, minutes: 30)),
          }),
        },
        now: later,
        version: later,
      );
      expect(
        [for (final alert in ringer.missed) alert.title],
        ['added, still on'],
      );
      // Told once per run.
      await list(
        {_work: work},
        now: later,
        version: later.add(const Duration(minutes: 1)),
      );
      expect(ringer.missed, hasLength(1));
    });

    test('on a ringer only while the app runs: every one since it last '
        'could ring', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      final work = _calendar({
        'rang': _monday.add(const Duration(minutes: 30)),
        'missed': _monday.add(const Duration(hours: 2)),
      });
      await list({_work: work});
      await planner.handle(
        (ticket) =>
            Rang(now: _monday.add(const Duration(minutes: 15)), ticket: ticket),
      );
      await planner.close();
      final later = _monday.add(const Duration(hours: 2));
      final next = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: next, store: store);
      await start(now: later);
      await list({_work: work}, now: later);
      expect([for (final alert in next.missed) alert.title], ['missed']);
    });

    test('on a ringer that rings while closed: one that rang while the '
        'app ran is no missed one at the next start', () async {
      await start();
      final work = _calendar({'rang': _monday.add(const Duration(hours: 1))});
      await list({_work: work});
      // It rang at 8:45; a listing at 9:30 no longer holds it; then the
      // app was ended without a word.
      await list({_work: work}, now: _monday.add(const Duration(minutes: 90)));
      await planner.close();
      planner = AlertPlanner(ringer: ringer, store: store);
      final later = _monday.add(const Duration(hours: 4));
      await start(now: later);
      // The calendar changed meanwhile, so it is read again.
      await list({_work: work}, now: later, version: later);
      expect(ringer.missed, isEmpty);
    });

    test('a calendar shown only later in a run tells none and rings only '
        'what is still to come', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      await list({});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      planner = AlertPlanner(ringer: ringer, store: store);
      final started = _monday.add(const Duration(hours: 2));
      await start(now: started);
      await list({}, now: started);
      // Later the user shows a calendar in the tab.
      final shown = started.add(const Duration(minutes: 20));
      await list({
        _work: _calendar({
          // Rang 9:55, before the start.
          'before the start': started.add(const Duration(minutes: 10)),
          // Rang 10:05, after it.
          'after the start': started.add(const Duration(minutes: 20)),
          // Rings 10:45.
          'to come': started.add(const Duration(hours: 1)),
        }),
      }, now: shown);
      expect(ringer.missed, isEmpty);
      expect(ringer.titles, ['to come']);
    });

    test('a calendar shown before the run but listed later in it (its '
        'folder was slow) rings from the start and tells those missed '
        'before', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      await list({_work: _calendar({})});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      planner = AlertPlanner(ringer: ringer, store: store);
      final started = _monday.add(const Duration(hours: 2));
      await start(now: started);
      // Its folder isn't listed yet.
      await list({}, now: started, sees: (file) => file != _work);
      final listed = started.add(const Duration(minutes: 20));
      await list({
        _work: _calendar({
          'before the start': started.add(const Duration(minutes: 10)),
          'after the start': started.add(const Duration(minutes: 20)),
        }),
      }, now: listed);
      expect(
        [for (final alert in ringer.missed) alert.title],
        ['before the start'],
      );
      expect(ringer.titles, ['after the start']);
    });

    test('a calendar whose folder was unreadable on a new day still counts '
        'as planned at the next start', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      await list({_work: _calendar({})});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      // The next day its folder can't be read.
      final tuesday = _monday.add(const Duration(days: 1));
      planner = AlertPlanner(ringer: ringer, store: store);
      await start(now: tuesday);
      await list({}, now: tuesday, sees: (file) => file != _work);
      await planner.close();
      // Restarted; the folder lists late.
      planner = AlertPlanner(ringer: ringer, store: store);
      final started = tuesday.add(const Duration(hours: 2));
      await start(now: started);
      await list({}, now: started, sees: (file) => file != _work);
      await list({
        _work: _calendar({
          'after the start': started.add(const Duration(minutes: 20)),
        }),
      }, now: started.add(const Duration(minutes: 20)));
      expect(ringer.titles, ['after the start']);
    });

    test('a run ended before any listing still leaves the missed ones '
        'for the next', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      await list({});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      final work = _calendar({'missed': _monday.add(const Duration(hours: 2))});
      // A run that started and was ended before it listed anything.
      planner = AlertPlanner(ringer: ringer, store: store);
      await start(now: _monday.add(const Duration(hours: 2)));
      await planner.close();
      planner = AlertPlanner(ringer: ringer, store: store);
      final later = _monday.add(const Duration(hours: 2, minutes: 30));
      await start(now: later);
      await list({_work: work}, now: later);
      expect([for (final alert in ringer.missed) alert.title], ['missed']);
    });

    test('a calendar planned before a run that ended before any listing '
        'still rings from the start when its folder lists late', () async {
      ringer = _Ringer(ringsWhileClosed: false);
      planner = AlertPlanner(ringer: ringer, store: store);
      await start();
      await list({_work: _calendar({})});
      await planner.handle((ticket) => Stopping(now: _monday, ticket: ticket));
      await planner.close();
      // A run that started and was ended before it listed anything.
      planner = AlertPlanner(ringer: ringer, store: store);
      await start(now: _monday.add(const Duration(hours: 1)));
      await planner.close();
      planner = AlertPlanner(ringer: ringer, store: store);
      final started = _monday.add(const Duration(hours: 2));
      await start(now: started);
      await list({}, now: started, sees: (file) => file != _work);
      await list({
        _work: _calendar({
          'after the start': started.add(const Duration(minutes: 20)),
        }),
      }, now: started.add(const Duration(minutes: 20)));
      expect(ringer.titles, ['after the start']);
    });

    test(
      'a repeating one missed many times is told once, its latest',
      () async {
        ringer = _Ringer(ringsWhileClosed: false);
        planner = AlertPlanner(ringer: ringer, store: store);
        await start();
        await list({});
        await planner.handle(
          (ticket) => Stopping(now: _monday, ticket: ticket),
        );
        await planner.close();
        planner = AlertPlanner(ringer: ringer, store: store);
        final later = _monday.add(const Duration(days: 5));
        await start(now: later);
        await list({
          _work: Calendar.read(
            'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VTODO\nUID:water\n'
            'SUMMARY:Water the plants\nDUE:20261116T120000\n'
            'RRULE:FREQ=DAILY\nBEGIN:VALARM\nACTION:DISPLAY\n'
            'TRIGGER;RELATED=END:-PT15M\nEND:VALARM\nEND:VTODO\n'
            'END:VCALENDAR\n',
          )!,
        }, now: later);
        expect(
          [for (final alert in ringer.missed) alert.start],
          [DateTime(2026, 11, 20, 12)],
        );
      },
    );

    test('none on the first run', () async {
      await start();
      await list({
        _work: _calendar({
          'past': _monday.subtract(const Duration(minutes: 5)),
        }),
      });
      expect(ringer.missed, isEmpty);
    });
  });

  test('the ring state reads back as written', () async {
    await start();
    await list({
      _work: _calendar({'meeting': _monday.add(const Duration(hours: 3))}),
    });
    final kept = planner.state.ring;
    final read = RingState.fromJson(kept.toJson());
    expect(read.handed, kept.handed);
    expect(read.plans, kept.plans);
    expect(read.nextNumber, kept.nextNumber);
    expect(read.lastAlive, kept.lastAlive);
    expect(read, kept);
  });
}
