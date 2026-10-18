import 'package:flutter/foundation.dart';

import 'checked_items.dart';
import 'note_view.dart';

/// How this device shows one note: view settings, not properties of the
/// note, so they are kept per device and never synced.
@immutable
final class NoteSettings {
  const NoteSettings({
    this.view,
    this.pinned = false,
    this.checkedItems = CheckedItems.doneSection,
  });

  /// Nothing chosen yet.
  static const defaults = NoteSettings();

  /// The view the note was last shown in; `null` if never.
  final NoteView? view;

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Where a checklist's checked items go.
  final CheckedItems checkedItems;

  bool get isDefault => this == defaults;

  NoteSettings withView(NoteView view) =>
      NoteSettings(view: view, pinned: pinned, checkedItems: checkedItems);

  NoteSettings withPinned({required bool pinned}) =>
      NoteSettings(view: view, pinned: pinned, checkedItems: checkedItems);

  NoteSettings withCheckedItems(CheckedItems checkedItems) =>
      NoteSettings(view: view, pinned: pinned, checkedItems: checkedItems);

  @override
  bool operator ==(Object other) =>
      other is NoteSettings &&
      other.view == view &&
      other.pinned == pinned &&
      other.checkedItems == checkedItems;

  @override
  int get hashCode => Object.hash(view, pinned, checkedItems);
}
