import 'package:collection/collection.dart';

import '../read/component.dart';
import 'calendar_item.dart';

/// What names a unit across texts of one calendar: the grain of reading,
/// editing and merging.
sealed class UnitKey {
  const UnitKey();
}

/// All components of one kind ([component]: `VEVENT`, `VTODO`, ...) with
/// one `UID`: for events and tasks a series with its changed dates, or
/// one event or task.
final class UidKey extends UnitKey {
  const UidKey(this.component, this.uid);

  /// The key of the event [uid].
  UidKey.event(String uid) : this(ItemKind.event.component, uid);

  /// The key of the task [uid].
  UidKey.task(String uid) : this(ItemKind.task.component, uid);

  /// The components' name, upper case.
  final String component;
  final String uid;

  /// The kind of item it holds; `null` if none (another component).
  ItemKind? get kind => ItemKind.named(component);

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
  CalendarUnit.read(this.key, this.parts, this.components);

  /// A unit an edit made: printed fresh from [components].
  CalendarUnit.edited(this.key, this.components)
    : parts = [components.map((component) => component.printed).join()];

  final UnitKey key;
  final List<String> parts;
  final List<Component> components;

  /// Its whole text, its parts in order.
  String get text => parts.join();

  /// The event or task it holds; `null` for none. Worked out once, so a
  /// unit an edit leaves alone keeps its item in the edited calendar.
  late final CalendarItem? item = CalendarItem.of(this);

  /// The time zones its components read times by: a `TZID` on any of
  /// their lines. Worked out each time it is asked.
  Iterable<String> get zonesNamed => components.expand(_zonesIn);
}

/// The zones [component] and the components in it name by `TZID`.
Iterable<String> _zonesIn(Component component) => [
  for (final line in component.properties) ?line.param('TZID'),
  for (final child in component.children) ..._zonesIn(child),
];

/// The kinds of calendar item: events (`VEVENT`) and tasks (`VTODO`).
/// The one place a component's name tells its kind.
enum ItemKind {
  event('VEVENT'),
  task('VTODO');

  const ItemKind(this.component);

  /// The name of its components.
  final String component;

  /// The kind of a component named [component]; `null` if it is no item.
  static ItemKind? named(String component) =>
      values.where((kind) => kind.component == component).firstOrNull;
}
