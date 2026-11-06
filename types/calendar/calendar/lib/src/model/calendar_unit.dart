import '../read/component.dart';

/// What names a unit across texts of one calendar: the grain of reading,
/// editing and merging.
sealed class UnitKey {
  const UnitKey();
}

/// All components of one kind ([component]: `VEVENT`, `VTODO`, ...) with
/// one `UID`: for events a series with its changed occurrences, or one
/// event.
final class UidKey extends UnitKey {
  const UidKey(this.component, this.uid);

  /// The key of the event [uid].
  const UidKey.event(this.uid) : component = 'VEVENT';

  /// The components' name, upper case.
  final String component;
  final String uid;

  @override
  bool operator ==(Object other) =>
      other is UidKey && other.component == component && other.uid == uid;

  @override
  int get hashCode => Object.hash(component, uid);
}

/// A time zone block (`VTIMEZONE`) with one `TZID`: its events' times
/// read by it, so a calendar holds one per zone. Never an edit of the
/// user's: a merge doesn't count it as lost.
final class ZoneKey extends UnitKey {
  const ZoneKey(this.zone);

  final String zone;

  @override
  bool operator ==(Object other) => other is ZoneKey && other.zone == zone;

  @override
  int get hashCode => zone.hashCode;
}

/// Anything else (a component without `UID`, lines the app doesn't
/// read): named by its text, and by how many with the same
/// text come before it in the same calendar ([nth]).
final class TextKey extends UnitKey {
  const TextKey(this.text, this.nth);

  final String text;
  final int nth;

  @override
  bool operator ==(Object other) =>
      other is TextKey && other.text == text && other.nth == nth;

  @override
  int get hashCode => Object.hash(text, nth);
}

/// One unit of a calendar: its [key], its [components] (none for lines
/// that are no component), and its text in [parts]: as read, one part per
/// block of the file (the parts of one event may lie apart), or printed
/// fresh as one part after an edit.
final class CalendarUnit {
  /// A unit as read: [parts] hold its blocks' lines as they were.
  const CalendarUnit.read(this.key, this.parts, this.components);

  /// A unit an edit made: printed fresh from [components].
  CalendarUnit.edited(this.key, this.components)
    : parts = [components.map((component) => component.printed).join()];

  final UnitKey key;
  final List<String> parts;
  final List<Component> components;

  /// Its whole text, its parts in order.
  String get text => parts.join();

  /// The time zones its components read times by: a `TZID` on any of
  /// their lines. Worked out each time it is asked.
  Iterable<String> get zonesNamed => components.expand(_zonesIn);
}

/// The zones [component] and the components in it name by `TZID`.
Iterable<String> _zonesIn(Component component) => [
  for (final line in component.properties) ?line.param('TZID'),
  for (final child in component.children) ..._zonesIn(child),
];
