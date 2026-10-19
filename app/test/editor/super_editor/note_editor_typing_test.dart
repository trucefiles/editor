import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// Typing list marks and splitting items in Visual edit.
void main() {
  /// Types [typed] on the empty line below a title; returns the file text.
  Future<String> typeOnEmptyLine(WidgetTester tester, String typed) async {
    final text = FakeNoteText('Title\n');
    await pumpNoteEditor(tester, text);
    await tester.caretIn(nodeOf<ParagraphNode>(index: 1), 0);
    await tester.typeImeText(typed);
    return text.text;
  }

  for (final typed in ['-5 kg', '*it* ok', '1.5 kg', '+1']) {
    testWidgets('a mark without a space stays text: $typed', (tester) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n$typed');
    });
  }

  for (final (typed, kind) in [
    ('- milk', 'bullet'),
    ('* milk', 'bullet'),
    ('1. milk', 'numbered'),
    ('- [ ] milk', 'checkbox'),
  ]) {
    testWidgets('a mark and a space start a $kind item: $typed', (
      tester,
    ) async {
      expect(await typeOnEmptyLine(tester, typed), 'Title\n$typed');
      final item = SuperEditorInspector.findDocument()!.last;
      expect(item, isNot(isA<ParagraphNode>()));
      expect((item as TextNode).text.toPlainText(), 'milk');
    });
  }
}
