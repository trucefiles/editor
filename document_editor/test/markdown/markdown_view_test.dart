import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
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
    final read = MarkdownView.of(ViewSettings({'mode': 'grid', 'checked': 3}));

    expect(read.mode, isNull);
    expect(read.checkedItems, CheckedItems.moveToEnd);
  });

  test('kept settings never change after they are made', () {
    final json = <String, Object?>{'mode': 'read'};
    final view = ViewSettings(json);
    json['mode'] = 'visual';

    expect(MarkdownView.of(view).mode, EditMode.read);
    expect(() => view.json['mode'] = 'visual', throwsUnsupportedError);
  });
}
