import '../read/component.dart';
import '../read/values.dart';

/// When one alarm (`VALARM`) of an item rings: one that shows or sounds
/// (`DISPLAY`, `AUDIO`); others (e.g. a mail) never ring on this device.
/// Relative to its item's date ([RelativeAlarm]) or at a fixed time
/// ([AbsoluteAlarm]).
sealed class Alarm {
  const Alarm(this.trigger, {required this.shows});

  /// [component]'s alarm; `null` if it is no alarm that rings, or its
  /// trigger can't be read.
  static Alarm? of(Component component) {
    if (component.name != 'VALARM') return null;
    final action = component.value('ACTION')?.trim().toUpperCase();
    if (action != 'DISPLAY' && action != 'AUDIO') return null;
    final shows = action == 'DISPLAY';
    final trigger = component.property('TRIGGER');
    if (trigger == null) return null;
    final written = trigger.unfolded;
    if (trigger.param('VALUE')?.toUpperCase() == 'DATE-TIME') {
      return switch (timeOf(trigger)) {
        final time? => AbsoluteAlarm(written, time.local.toUtc(), shows: shows),
        null => null,
      };
    }
    return switch (durationOf(trigger.value)) {
      final offset? => RelativeAlarm(
        written,
        offset,
        fromEnd: trigger.param('RELATED')?.toUpperCase() == 'END',
        shows: shows,
      ),
      null => null,
    };
  }

  /// Its `TRIGGER` line as written: tells it apart from its item's other
  /// alarms.
  final String trigger;

  /// Whether it shows on screen (`DISPLAY`); else it only sounds.
  final bool shows;
}

/// An alarm [offset] after its date's start (or, [fromEnd], its end; a
/// task's due time); before it where negative.
final class RelativeAlarm extends Alarm {
  const RelativeAlarm(
    super.trigger,
    this.offset, {
    required this.fromEnd,
    required super.shows,
  });

  final Duration offset;
  final bool fromEnd;

  /// When it rings for a date counted from [base] (on this device's
  /// clock): whole days on the calendar, as RFC 5545 counts them, so a
  /// clock change between doesn't move it; the rest exactly.
  DateTime ringsAt(DateTime base) {
    final days = offset.inDays;
    final onDay = DateTime(
      base.year,
      base.month,
      base.day + days,
      base.hour,
      base.minute,
      base.second,
    );
    return onDay.add(offset - Duration(days: days));
  }
}

/// An alarm at a fixed moment [at] (UTC), whatever its item's dates.
final class AbsoluteAlarm extends Alarm {
  const AbsoluteAlarm(super.trigger, this.at, {required super.shows});

  final DateTime at;
}
