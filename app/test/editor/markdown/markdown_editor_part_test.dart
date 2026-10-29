import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

import '../../support.dart';

/// A Markdown part over [text], on a page that keeps its view settings
/// and has a file unless [hasFile] is false.
({MarkdownEditorPart part, List<ViewSettings> kept}) _part(
  String text, {
  bool readOnly = false,
  bool hasFile = true,
}) {
  final kept = <ViewSettings>[ViewSettings.none];
  final part = MarkdownEditorPart(
    (
      text: text,
      version: const Version(1),
      view: MarkdownView(mode: EditMode.markdown).settings,
      readOnly: readOnly,
      isNew: false,
    ),
    EditorPage(
      keepView: (change) => kept.add(change(kept.last)),
      withFile: (action) async {
        if (hasFile) {
          await action(listedDocument(folderAt(Directory.systemTemp)));
        }
      },
    ),
  );
  addTearDown(() async {
    part.dispose();
    await part.editor.close();
  });
  return (part: part, kept: kept);
}

void main() {
  test('a picked mode shows, is kept, and the page hears of it', () {
    final (:part, :kept) = _part('# Notes');
    var heard = 0;
    part.changes.listen((_) => heard++);

    part.pick(EditMode.visual);

    expect(part.mode, EditMode.visual);
    expect(part.gate.state.mode, EditMode.visual);
    expect(MarkdownView.of(kept.last).mode, EditMode.visual);
    expect(heard, 1);
  });

  test('picking the mode that shows changes nothing', () {
    final (:part, :kept) = _part('# Notes');
    var heard = 0;
    part.changes.listen((_) => heard++);

    part.pick(EditMode.markdown);

    expect(kept, [ViewSettings.none]);
    expect(heard, 0);
  });

  test('read only shows Read, and the picked mode once editable', () {
    final (:part, kept: _) = _part('# Notes', readOnly: true);

    expect(part.gate.state.mode, EditMode.read);
    expect(part.isEditing, isFalse);

    part.showReadOnly(readOnly: false);

    expect(part.gate.state.mode, EditMode.markdown);
    expect(part.isEditing, isTrue);
  });

  group('checked items', () {
    test('the chosen place is kept', () async {
      final (:part, :kept) = _part('- [x] done');

      await part.chooseCheckedItems(
        CheckedItems.moveToEnd,
        (_) async => CheckedItems.inPlace,
      );

      expect(MarkdownView.of(kept.last).checkedItems, CheckedItems.inPlace);
    });

    test('the same place, or none, keeps nothing', () async {
      final (:part, :kept) = _part('- [x] done');

      await part.chooseCheckedItems(
        CheckedItems.moveToEnd,
        (current) async => current,
      );
      await part.chooseCheckedItems(CheckedItems.moveToEnd, (_) async => null);

      expect(kept, [ViewSettings.none]);
    });

    test('are not asked about without a file', () async {
      final (:part, :kept) = _part('- [x] done', hasFile: false);
      var asked = false;

      await part.chooseCheckedItems(CheckedItems.moveToEnd, (_) async {
        asked = true;
        return CheckedItems.inPlace;
      });

      expect(asked, isFalse);
      expect(kept, [ViewSettings.none]);
    });
  });
}
