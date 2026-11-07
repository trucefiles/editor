import 'package:test/test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

void main() {
  TabPlace placeOf(Map<String, Object?> json) =>
      CalendarView.of(ViewSettings(json)).tab;

  test('each place is kept and read back', () {
    for (final place in TabPlace.values) {
      expect(CalendarView.of(CalendarView(tab: place).settings).tab, place);
    }
    expect(const CalendarView().settings.json, isEmpty);
  });

  test('each view kind is kept and read back, beside the place', () {
    for (final kind in CalendarViewKind.values) {
      final kept = CalendarView.of(
        const CalendarView(tab: TabPlace.off).withKind(kind).settings,
      );
      expect((kept.tab, kept.kind), (TabPlace.off, kind));
    }
  });

  test('a new place keeps the view kind, and a new kind the place', () {
    const view = CalendarView(tab: TabPlace.hidden, kind: CalendarViewKind.day);
    final placed = view.withTab(TabPlace.shown);
    expect((placed.tab, placed.kind), (TabPlace.shown, CalendarViewKind.day));
    final picked = view.withKind(CalendarViewKind.week);
    expect((picked.tab, picked.kind), (TabPlace.hidden, CalendarViewKind.week));
  });

  test('no view kind kept, or one it cannot read, opens in the month', () {
    CalendarViewKind kindOf(Map<String, Object?> json) =>
        CalendarView.of(ViewSettings(json)).kind;
    expect(kindOf({}), CalendarViewKind.month);
    expect(kindOf({'kind': 'year'}), CalendarViewKind.month);
    expect(kindOf({'kind': 3}), CalendarViewKind.month);
  });

  test('the old "not in the tab" reads as off; anything else as shown', () {
    expect(placeOf({'inTab': false}), TabPlace.off);
    expect(placeOf({'inTab': true}), TabPlace.shown);
    expect(placeOf({'tab': 'unknown'}), TabPlace.shown);
    expect(placeOf({}), TabPlace.shown);
  });
}
