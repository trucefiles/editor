import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

/// The one rule for an occurrence's color: its own color ([ownColor]),
/// else its health entry kind's, else [calendar]'s color.
Color occurrenceColor(Occurrence occurrence, Color calendar) =>
    ownColor(occurrence) ??
    switch (occurrence.part) {
      EventPart(health: final entry?) => healthKindColor(entry),
      _ => calendar,
    };

/// The color [occurrence]'s event gives itself, if it gives one.
Color? ownColor(Occurrence occurrence) => switch (occurrence.part) {
  EventPart(color: EventColor(:final rgb?)) => Color(0xFF000000 | rgb),
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
