import 'package:truce_calendar/truce_calendar.dart' show ItemKind;
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';

import '../common/time_texts.dart';

/// The title an alert shows: its item's, or what it is if it has none.
String alertTitle(PlannedAlert alert) => switch (alert.title.trim()) {
  '' => alert.kind == ItemKind.task ? 'A task' : 'An event',
  final title => title,
};

/// What an alert says below its title: when its date is, in [texts].
String alertWhen(PlannedAlert alert, TimeTexts texts) => switch ((
  alert.kind,
  alert.start,
)) {
  (_, null) => 'A task with no date',
  (ItemKind.task, final due?) => 'Due ${texts.day(due, allDay: alert.allDay)}',
  (ItemKind.event, final start?) => texts.day(start, allDay: alert.allDay),
};

/// What a missed alert says below its title.
String missedWhen(PlannedAlert alert, TimeTexts texts) =>
    'Missed. ${alertWhen(alert, texts)}';
