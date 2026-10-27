import 'package:flutter/foundation.dart';

import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

/// How this device shows one document: view settings, not properties of the
/// document, so they are kept per device and never synced.
@immutable
final class DocumentSettings {
  const DocumentSettings({
    this.mode,
    this.pinned = false,
    this.checkedItems = CheckedItems.moveToEnd,
  });

  /// Nothing chosen yet.
  static const defaults = DocumentSettings();

  /// The mode the document was last shown in; `null` if never.
  final EditMode? mode;

  /// Shown before documents that are not pinned.
  final bool pinned;

  /// Where a checklist's checked items go.
  final CheckedItems checkedItems;

  bool get isDefault => this == defaults;

  DocumentSettings withMode(EditMode mode) =>
      DocumentSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  DocumentSettings withPinned({required bool pinned}) =>
      DocumentSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  DocumentSettings withCheckedItems(CheckedItems checkedItems) =>
      DocumentSettings(mode: mode, pinned: pinned, checkedItems: checkedItems);

  @override
  bool operator ==(Object other) =>
      other is DocumentSettings &&
      other.mode == mode &&
      other.pinned == pinned &&
      other.checkedItems == checkedItems;

  @override
  int get hashCode => Object.hash(mode, pinned, checkedItems);
}
