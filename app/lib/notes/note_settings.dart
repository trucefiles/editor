import 'package:flutter/foundation.dart';

import 'note_view.dart';

/// How this device shows one note: view settings, not properties of the
/// note, so they are kept per device and never synced.
@immutable
final class NoteSettings {
  const NoteSettings({this.view, this.pinned = false, this.doneSection = true});

  /// Nothing chosen yet.
  static const defaults = NoteSettings();

  /// The view the note was last shown in; `null` if never.
  final NoteView? view;

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Whether a checklist shows its checked items apart, in a "Done"
  /// section at the bottom. View only: the file order never changes.
  final bool doneSection;

  bool get isDefault => this == defaults;

  NoteSettings withView(NoteView view) =>
      NoteSettings(view: view, pinned: pinned, doneSection: doneSection);

  NoteSettings withPinned({required bool pinned}) =>
      NoteSettings(view: view, pinned: pinned, doneSection: doneSection);

  NoteSettings withDoneSection({required bool doneSection}) =>
      NoteSettings(view: view, pinned: pinned, doneSection: doneSection);

  @override
  bool operator ==(Object other) =>
      other is NoteSettings &&
      other.view == view &&
      other.pinned == pinned &&
      other.doneSection == doneSection;

  @override
  int get hashCode => Object.hash(view, pinned, doneSection);
}
