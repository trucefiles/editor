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

  test('the old "not in the tab" reads as off; anything else as shown', () {
    expect(placeOf({'inTab': false}), TabPlace.off);
    expect(placeOf({'inTab': true}), TabPlace.shown);
    expect(placeOf({'tab': 'unknown'}), TabPlace.shown);
    expect(placeOf({}), TabPlace.shown);
  });
}
