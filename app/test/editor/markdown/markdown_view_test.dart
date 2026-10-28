import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/view_settings.dart';
import 'package:truce_editor/editor/markdown/markdown_view.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

void main() {
  test('reads back what it kept', () {
    const view = MarkdownView(
      mode: EditMode.read,
      checkedItems: CheckedItems.inPlace,
    );

    final read = MarkdownView.of(view.settings);

    expect(read.mode, EditMode.read);
    expect(read.checkedItems, CheckedItems.inPlace);
  });

  test('nothing chosen is kept as none', () {
    expect(const MarkdownView().settings, ViewSettings.none);
    expect(
      const MarkdownView().withCheckedItems(CheckedItems.moveToEnd).settings,
      ViewSettings.none,
    );
  });

  test('what it cannot read is as never chosen', () {
    final read = MarkdownView.of(
      const ViewSettings({'mode': 'grid', 'checked': 3}),
    );

    expect(read.mode, isNull);
    expect(read.checkedItems, CheckedItems.moveToEnd);
  });
}
