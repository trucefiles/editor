import 'package:truce_core/truce_core.dart';

import '../health/cycle.dart';
import '../model/calendar.dart';
import '../recurrence/occurrences.dart';

/// How a calendar's preview shows, as of [now]: its next [count]
/// occurrences, each as [occurrenceLine] writes it; for a health calendar
/// its cycle, as [cycleLine] writes it. The app gives the words and
/// formats, so this package knows no locale.
final class CalendarPreview {
  const CalendarPreview({
    required this.now,
    required this.occurrenceLine,
    required this.cycleLine,
    this.count = 5,
  });

  final DateTime now;
  final String Function(Occurrence occurrence) occurrenceLine;
  final String Function(CyclePrediction cycle, DateTime today) cycleLine;
  final int count;
}

/// How far ahead a preview looks for occurrences.
const previewAhead = Duration(days: 366);

/// What lists show of a calendar's text: its name as the title, and its
/// next occurrences (or cycle) as the preview. A text that is no
/// calendar has no title and an empty preview.
final class CalendarSummary implements TextSummary<CalendarPreview> {
  CalendarSummary(String text) : calendar = Calendar.read(text);

  /// The calendar; `null` if the text is none.
  final Calendar? calendar;

  @override
  String? get title => firstLine.isEmpty ? null : firstLine;

  @override
  late final String firstLine = calendar?.name.trim() ?? '';

  @override
  String preview(CalendarPreview options) {
    final calendar = this.calendar;
    if (calendar == null) return '';
    if (calendar.isHealth) {
      return switch (predictCycle(periodDays(calendar), options.now)) {
        final cycle? => options.cycleLine(cycle, options.now),
        null => '',
      };
    }
    return occurrences(
      calendar,
      options.now,
      options.now.add(previewAhead),
    ).take(options.count).map(options.occurrenceLine).join('\n');
  }
}
