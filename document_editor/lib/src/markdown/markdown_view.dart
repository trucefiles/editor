import 'package:flutter/foundation.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

/// What a Markdown document keeps of how it shows on this device: the
/// mode it was last shown in and where its checked items go. Kept as the
/// document's [ViewSettings].
@immutable
final class MarkdownView {
  const MarkdownView({this.mode, this.checkedItems = CheckedItems.moveToEnd});

  /// [view] as Markdown kept it; what it can't read is as never chosen.
  factory MarkdownView.of(ViewSettings view) => MarkdownView(
    mode: EditMode.values.asNameMap()[view.json['mode']],
    checkedItems:
        CheckedItems.values.asNameMap()[view.json['checked']] ??
        CheckedItems.moveToEnd,
  );

  /// The mode the document was last shown in; `null` if never.
  final EditMode? mode;

  /// Where a checklist's checked items go.
  final CheckedItems checkedItems;

  /// As kept; what was never chosen is left out, so nothing chosen is
  /// [ViewSettings.none].
  ViewSettings get settings => ViewSettings({
    if (mode case final mode?) 'mode': mode.name,
    if (checkedItems != CheckedItems.moveToEnd) 'checked': checkedItems.name,
  });

  MarkdownView withMode(EditMode mode) =>
      MarkdownView(mode: mode, checkedItems: checkedItems);

  MarkdownView withCheckedItems(CheckedItems checkedItems) =>
      MarkdownView(mode: mode, checkedItems: checkedItems);
}
