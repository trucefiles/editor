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

  /// The step of [written], the units an edit wrote into [calendar],
  /// which became [edited]: only those whose text changed count; `null`
  /// if none did.
  static UnitsChanged? of(
    Calendar calendar,
    Calendar edited,
    List<CalendarUnit> written,
  ) {
    final after = {
      for (final CalendarUnit(:key) in written)
        if (edited.unitOf(key)! case final unit
            when unit.text != calendar.unitOf(key)?.text)
          key: unit,
    };
    if (after.isEmpty) return null;
    return UnitsChanged._({
      for (final key in after.keys) key: calendar.unitOf(key),
    }, after);
  }

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
