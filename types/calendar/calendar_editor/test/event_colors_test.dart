import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/ui/event_colors.dart';

/// The one occurrence of a calendar with one all-day event drafted as
/// [draft] on 3 November 2026.
Occurrence _one(EventDraft Function(DateTime day) draft) {
  final day = DateTime(2026, 11, 3);
  final calendar = applyEdit(
    Calendar.read(newCalendarText('Home'))!,
    AddEvent('a', draft(day), at: DateTime.utc(2026, 11)),
  );
  return occurrences(calendar, day, DateTime(2026, 11, 4)).single;
}

void main() {
  const calendar = Colors.teal;

  test("an event's own color comes first, then its health kind's, then "
      "its calendar's", () {
    EventDraft plain(DateTime day, {EventColor? color}) => EventDraft(
      summary: 'Gym',
      start: AllDay(day),
      end: AllDay(day.add(const Duration(days: 1))),
      color: color,
    );
    expect(occurrenceColor(_one(plain), calendar), calendar);
    expect(
      occurrenceColor(
        _one((day) => plain(day, color: const EventColor('red'))),
        calendar,
      ),
      const Color(0xFFFF0000),
    );
    expect(
      occurrenceColor(
        _one(
          (day) => EventDraft.health(const Medication('Ibu', dose: ''), day),
        ),
        calendar,
      ),
      healthKindColor(const Medication('', dose: '')),
    );
    expect(
      occurrenceColor(
        _one((day) => plain(day, color: const EventColor('no color'))),
        calendar,
      ),
      calendar,
      reason: 'a color it cannot read shows as none',
    );
  });

  test('only an event that gives itself a color has one of its own', () {
    EventDraft plain(DateTime day, {EventColor? color}) => EventDraft(
      summary: 'Gym',
      start: AllDay(day),
      end: AllDay(day.add(const Duration(days: 1))),
      color: color,
    );
    expect(ownColor(_one(plain)), isNull);
    expect(
      ownColor(_one((day) => plain(day, color: const EventColor('red')))),
      const Color(0xFFFF0000),
    );
    expect(
      ownColor(
        _one(
          (day) => EventDraft.health(const Medication('Ibu', dose: ''), day),
        ),
      ),
      isNull,
      reason: "a health kind's color is not the event's own",
    );
  });

  test('each health kind has a color of its own', () {
    const kinds = <HealthEntry>[
      Period(PeriodFlow.medium),
      Symptom('', level: 1),
      Medication('', dose: ''),
      Measure('', value: '', unit: ''),
      HealthNote(),
    ];
    expect(kinds.map(healthKindColor).toSet(), hasLength(kinds.length));
  });
}
