import 'package:flutter/foundation.dart';

import 'note_view.dart';

/// How this device shows one note: view settings, not properties of the
/// note, so they are kept per device and never synced.
@immutable
final class NoteSettings {
  const NoteSettings({
    this.view,
    this.pinned = false,
    this.doneSection = true,
    this.checkedToEnd = false,
  });

  /// Nothing chosen yet.
  static const defaults = NoteSettings();

  /// The view the note was last shown in; `null` if never.
  final NoteView? view;

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Whether a checklist shows its checked items apart, in a "Done"
  /// section at the bottom. View only: the file order never changes.
  final bool doneSection;

  /// Whether checking a checklist item moves it to the end of the list,
  /// and unchecking moves it back below the open items. Changes the file,
  /// as the user's own edit.
  final bool checkedToEnd;

  bool get isDefault => this == defaults;

  NoteSettings withView(NoteView view) => _copy(view: view);

  NoteSettings withPinned({required bool pinned}) => _copy(pinned: pinned);

  NoteSettings withDoneSection({required bool doneSection}) =>
      _copy(doneSection: doneSection);

  NoteSettings withCheckedToEnd({required bool checkedToEnd}) =>
      _copy(checkedToEnd: checkedToEnd);

  NoteSettings _copy({
    NoteView? view,
    bool? pinned,
    bool? doneSection,
    bool? checkedToEnd,
  }) => NoteSettings(
    view: view ?? this.view,
    pinned: pinned ?? this.pinned,
    doneSection: doneSection ?? this.doneSection,
    checkedToEnd: checkedToEnd ?? this.checkedToEnd,
  );

  @override
  bool operator ==(Object other) =>
      other is NoteSettings &&
      other.view == view &&
      other.pinned == pinned &&
      other.doneSection == doneSection &&
      other.checkedToEnd == checkedToEnd;

  @override
  int get hashCode => Object.hash(view, pinned, doneSection, checkedToEnd);
}
