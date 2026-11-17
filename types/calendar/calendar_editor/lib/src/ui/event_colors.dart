import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// The color [occurrence] shows in (see [shownColor]).
Color occurrenceColor(Occurrence occurrence, Color calendar) =>
    shownColor(occurrence.part, calendar);

/// The one rule for an event's or task's color: its own color
/// ([partColor]), else its health entry kind's, else [calendar]'s color.
Color shownColor(ItemPart part, Color calendar) =>
    partColor(part) ??
    switch (part) {
      EventPart(health: final entry?) => healthKindColor(entry),
      _ => calendar,
    };

/// The color [occurrence]'s event or task gives itself, if it gives one.
Color? ownColor(Occurrence occurrence) => partColor(occurrence.part);

/// The color [part] gives itself, if it gives one.
Color? partColor(ItemPart part) => switch (part.color) {
  EventColor(:final rgb?) => Color(0xFF000000 | rgb),
  _ => null,
};

/// The color a health entry of [entry]'s kind shows in.
Color healthKindColor(HealthEntry entry) => switch (entry) {
  Period() => const Color(0xFFD9475B),
  Symptom() => const Color(0xFFE08A2E),
  Medication() => const Color(0xFF3E7CC9),
  Measure() => const Color(0xFF2E9C8F),
  HealthNote() => const Color(0xFF8A8F98),
};

/// The colors the event form offers, as written into the file: CSS color
/// names, as the standard asks.
const eventColorChoices = [
  EventColor('tomato'),
  EventColor('orange'),
  EventColor('gold'),
  EventColor('mediumseagreen'),
  EventColor('teal'),
  EventColor('dodgerblue'),
  EventColor('slateblue'),
  EventColor('orchid'),
  EventColor('gray'),
];
