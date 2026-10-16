/// How the user marked one note. Synced through `NoteMarks`.
final class NoteMark {
  const NoteMark({this.pinned = false, this.color, this.doneSection = true});

  /// Not pinned, no color, the default "Done" section.
  static const none = NoteMark();

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Name of a color the app offers, e.g. `teal`; `null` for none. A name,
  /// not a value, so each app picks shades that fit its theme.
  final String? color;

  /// Whether a checklist shows its checked items apart, in a "Done"
  /// section at the bottom. View only: the file order never changes.
  final bool doneSection;

  bool get isNone => this == none;

  NoteMark withPinned({required bool pinned}) =>
      NoteMark(pinned: pinned, color: color, doneSection: doneSection);

  NoteMark withColor(String? color) =>
      NoteMark(pinned: pinned, color: color, doneSection: doneSection);

  NoteMark withDoneSection({required bool doneSection}) =>
      NoteMark(pinned: pinned, color: color, doneSection: doneSection);

  @override
  bool operator ==(Object other) =>
      other is NoteMark &&
      other.pinned == pinned &&
      other.color == color &&
      other.doneSection == doneSection;

  @override
  int get hashCode => Object.hash(pinned, color, doneSection);
}
