import 'package:flutter/foundation.dart';

import 'checked_items.dart';
import 'note_mode.dart';

/// How this device shows one note: view settings, not properties of the
/// note, so they are kept per device and never synced.
@immutable
final class NoteSettings {
  const NoteSettings({
    this.mode,
    this.pinned = false,
    this.checkedItems = CheckedItems.doneSection,
  });

  /// Nothing chosen yet.
  static const defaults = NoteSettings();

  /// The mode the note was last shown in; `null` if never.
  final NoteMode? mode;

  /// Shown before notes that are not pinned.
  final bool pinned;

  /// Where a checklist's checked items go.
  final CheckedItems checkedItems;

  bool get isDefault => this == defaults;

  NoteSettings withMode(NoteMode mode) =>
      NoteSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  NoteSettings withPinned({required bool pinned}) =>
      NoteSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  NoteSettings withCheckedItems(CheckedItems checkedItems) =>
      NoteSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  @override
  bool operator ==(Object other) =>
      other is NoteSettings &&
      other.mode == mode &&
      other.pinned == pinned &&
      other.checkedItems == checkedItems;

  @override
  int get hashCode => Object.hash(mode, pinned, checkedItems);
}
