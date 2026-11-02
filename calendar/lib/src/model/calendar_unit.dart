import '../read/component.dart';

/// What names a unit across texts of one calendar: the grain of reading,
/// editing and merging.
sealed class UnitKey {
  const UnitKey();
}

/// All events with one `UID`: a series with its changed occurrences, or
/// one event.
final class UidKey extends UnitKey {
  const UidKey(this.uid);

  final String uid;

  @override
  bool operator ==(Object other) => other is UidKey && other.uid == uid;

  @override
  int get hashCode => uid.hashCode;
}

/// Anything else (a time zone, a task, an event without `UID`, lines the
/// app doesn't read): named by its text, and by how many with the same
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
}
