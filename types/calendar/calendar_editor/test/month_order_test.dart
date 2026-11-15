import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar_editor/src/views/month_order.dart';

void main() {
  final day = DateTime.utc(2026, 11, 10);
  KalenderEvent event(int fromHour, int hours, {bool allDay = false}) =>
      KalenderEvent(
        start: day.add(Duration(hours: fromHour)),
        end: day.add(Duration(hours: fromHour + hours)),
        isAllDay: allDay,
      );

  List<KalenderEvent> ordered(List<KalenderEvent> events) => const MonthOrder()
      .generateFrame(
        visibleRange: FloatingDateTimeRange(
          start: FloatingDateTime.fromExternal(DateTime.utc(2026, 11, 9)),
          end: FloatingDateTime.fromExternal(DateTime.utc(2026, 11, 16)),
        ),
        events: events,
        textDirection: TextDirection.ltr,
        location: null,
        cache: null,
      )
      .events;

  test('timed events of a day go by start, a long one after an earlier '
      'short one', () {
    final short = event(8, 1);
    final long = event(10, 6);
    final early = event(7, 1);

    expect(ordered([long, short, early]), [early, short, long]);
  });

  test('all-day events and events over several days come first, longest '
      'first', () {
    final timed = event(6, 1);
    final allDay = event(0, 24, allDay: true);
    final threeDays = event(-24, 72);

    expect(ordered([timed, allDay, threeDays]), [threeDays, allDay, timed]);
  });
}
