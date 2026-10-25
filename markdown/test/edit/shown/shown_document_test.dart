import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/edit/shown/rows.dart';
import 'package:truce_markdown/src/edit/shown/shown_document.dart';
import 'package:truce_markdown/src/edit/shown/slot.dart';

/// Whether [text] shows the end gap last.
bool _endsInGap(String text) =>
    switch (ShownDocument(DocumentTree.read(text)).rows.lastOrNull) {
      TextRow(slot: GapSlot(gap: GapId.end)) => true,
      _ => false,
    };

void main() {
  test('the end gap shows where the last row has no text to type in', () {
    expect(_endsInGap(''), isTrue);
    expect(_endsInGap('a\n\n---'), isTrue);
    expect(_endsInGap('```\na\n```'), isTrue);
    expect(_endsInGap('- <div>\n  x\n  </div>'), isTrue);
    expect(_endsInGap('a'), isFalse);
    expect(_endsInGap('- a'), isFalse);
  });
}
