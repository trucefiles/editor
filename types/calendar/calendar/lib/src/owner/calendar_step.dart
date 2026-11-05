import 'package:truce_core/truce_core.dart' show UndoableEdit;

import '../model/calendar.dart';
import '../model/calendar_unit.dart';

/// What the editor shows on one side of a restored backup: the [text],
/// and the [calendar] read from it (`null` if it is no calendar).
typedef CalendarShown = ({String text, Calendar? calendar});

/// One edit of a calendar, kept to take back by undo and make again by
/// redo. A calendar edit is never typing, so steps never join.
sealed class CalendarStep implements UndoableEdit<CalendarStep> {
  const CalendarStep();

  @override
  CalendarStep joined(CalendarStep next) =>
      throw StateError('calendar edits are never typing');
}

/// A user's edit, kept as the units it changed alone: each as it was
/// [before] (`null` for one it added) and as it is [after].
final class UnitsChanged extends CalendarStep {
  const UnitsChanged._(this.before, this.after);

  /// The step of an edit of [calendar] into [edited] that wrote the
  /// units [written]; `null` if it wrote none.
  static UnitsChanged? of(
    Calendar calendar,
    Calendar edited,
    List<UnitKey> written,
  ) => written.isEmpty
      ? null
      : UnitsChanged._(
          Map.unmodifiable({
            for (final key in written) key: calendar.unitOf(key),
          }),
          Map.unmodifiable({
            for (final key in written) key: edited.unitOf(key)!,
          }),
        );

  final Map<UnitKey, CalendarUnit?> before;
  final Map<UnitKey, CalendarUnit> after;
}

/// A backup restored: the whole of what showed [before] and [after], as
/// it may differ anywhere in the file, or be no calendar.
final class TextReplaced extends CalendarStep {
  const TextReplaced(this.before, this.after);

  final CalendarShown before;
  final CalendarShown after;
}
