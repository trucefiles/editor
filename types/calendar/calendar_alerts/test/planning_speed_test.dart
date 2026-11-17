import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_alerts/src/planning.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_core/truce_core.dart';

/// A day's planning of all shown calendars, each read anew, at sizes well
/// past normal use: twenty calendars of a thousand events over three
/// years and twenty daily repeats, each with two alerts.
/// About 240 ms on a laptop; CI machines are up to twice as slow.
const _budget = Duration(milliseconds: 800);

String _two(int n) => n.toString().padLeft(2, '0');

String _at(DateTime time) =>
    '${time.year}${_two(time.month)}${_two(time.day)}'
    'T${_two(time.hour)}${_two(time.minute)}00';

const _alarms =
    'BEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-PT15M\nEND:VALARM\n'
    'BEGIN:VALARM\nACTION:DISPLAY\nTRIGGER:-P1D\nEND:VALARM\n';

Calendar _busy(int calendar) => Calendar.read(
  'BEGIN:VCALENDAR\nVERSION:2.0\n'
  '${[for (var i = 0; i < 1000; i++) 'BEGIN:VEVENT\nUID:e$calendar-$i\nSUMMARY:Event $i\nDTSTART:${_at(DateTime(2025, 1, 1, 9).add(Duration(hours: 26 * i)))}\nDURATION:PT1H\n${_alarms}END:VEVENT\n'].join()}'
  '${[for (var i = 0; i < 20; i++) 'BEGIN:VEVENT\nUID:r$calendar-$i\nSUMMARY:Daily $i\nDTSTART:${_at(DateTime(2024, 1, 1, 7 + i % 10))}\nDURATION:PT30M\nRRULE:FREQ=DAILY\n${_alarms}END:VEVENT\n'].join()}'
  'END:VCALENDAR\n',
)!;

void main() {
  test('a day of all shown calendars is planned within budget', () {
    final calendars = {
      for (var index = 0; index < 20; index++)
        (
          folder: const FolderId('fake', 'a'),
          path: RelPath.parse('c$index.ics')!,
        ): _busy(
          index,
        ),
    };
    final times = [
      for (var day = 1; day < 8; day++)
        () {
          final now = DateTime(2026, 11, day, 8);
          final watch = Stopwatch()..start();
          final step = planStep(
            PlannerState(ring: RingState.none, startedAt: now),
            CalendarsListed(
              now: now,
              zone: 'Europe/Berlin',
              calendars: {
                for (final MapEntry(key: file, value: calendar)
                    in calendars.entries)
                  file: (version: '$day', calendar: calendar),
              },
              sees: (_) => true,
            ),
            ringsWhileClosed: true,
          );
          expect(step.changes, hasLength(mostPlanned));
          return watch.elapsed;
        }(),
    ]..sort();

    expect(times[times.length ~/ 2], lessThan(_budget));
  });
}
