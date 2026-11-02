import 'calendar_view_kind.dart';

/// The view calendars open in, kept on this device by the app: the one
/// picked [last]; [keep] keeps a new pick (done once the future ends).
final class CalendarViewChoice {
  const CalendarViewChoice({required this.last, required this.keep});

  final CalendarViewKind Function() last;
  final Future<void> Function(CalendarViewKind kind) keep;
}
