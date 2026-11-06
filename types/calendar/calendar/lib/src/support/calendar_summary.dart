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
  /// What lists show of [text], read.
  CalendarSummary(String text) : this._(Calendar.read(text), text);

  /// What lists show of [calendar]'s text, from it as read.
  CalendarSummary.of(Calendar calendar) : this._(calendar, null);

  CalendarSummary._(this.calendar, this._noCalendar);

  /// The text, kept only when it is no calendar.
  final String? _noCalendar;

  /// The calendar; `null` if the text is none.
  final Calendar? calendar;

  /// The calendar's name; `null` if it has none, so the file's name
  /// shows.
  @override
  late final String? title = switch (calendar?.name.trim()) {
    final name? when name.isNotEmpty => name,
    _ => null,
  };

  /// The calendar's name; a calendar with none is named after its kind
  /// ("Calendar", "Health calendar"), as a new file is.
  @override
  late final String firstLine =
      title ??
      switch (calendar) {
        final calendar? => kindName(health: calendar.isHealth),
        null => '',
      };

  /// What a search finds: the name and each event's title, place and
  /// notes, deleted events left out; a text that is no calendar as it is.
  late final String searchText = switch (calendar) {
    final calendar? => [
      calendar.name,
      for (final event in calendar.events)
        for (final part in [event.series, ...event.changed])
          if (!part.deleted) ...[part.summary, part.location, part.description],
    ].where((text) => text.isNotEmpty).join('\n'),
    null => _noCalendar!,
  };

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
    return _shown(calendar, options).map(options.occurrenceLine).join('\n');
  }

  /// When [preview] with [options] may change though the text doesn't:
  /// once the first of the occurrences it shows ends, or for a health
  /// calendar the next day; `null` if nothing it shows passes.
  DateTime? holdsUntil(CalendarPreview options) {
    final calendar = this.calendar;
    if (calendar == null) return null;
    final now = options.now;
    if (calendar.isHealth) return DateTime(now.year, now.month, now.day + 1);
    return _shown(calendar, options)
        .map((occurrence) => occurrence.end)
        .fold<DateTime?>(
          null,
          (first, end) => first == null || end.isBefore(first) ? end : first,
        );
  }

  /// The occurrences a preview with [options] shows.
  List<Occurrence> _shown(Calendar calendar, CalendarPreview options) =>
      occurrences(
        calendar,
        options.now,
        options.now.add(previewAhead),
      ).take(options.count).toList();
}
