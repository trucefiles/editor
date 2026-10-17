import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto/se_adapter.dart';
import 'package:proto/se_live_preview.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

Iterable<String> shownTexts(WidgetTester tester) => tester
    .widgetList<RichText>(find.byWidgetPredicate((w) => w is RichText))
    .map((t) => t.text.toPlainText())
    .where((t) => t.trim().isNotEmpty);

Future<void> tapAtRaw(WidgetTester tester, String nodeId, int offset) async {
  final layout = SuperEditorInspector.findDocumentLayout();
  final component = layout.getComponentByNodeId(nodeId)!;
  final local = component.getOffsetForPosition(TextNodePosition(offset: offset));
  final box = component.context.findRenderObject() as RenderBox;
  await tester.tapAt(box.localToGlobal(local + const Offset(1, 5)));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('raw Markdown only on the line with the caret', (tester) async {
    final model = SeChecklist('- [ ] bread **fresh**\n- [ ] see [shop](https://x.y) now');
    final rendered = <String, Rendered>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperEditor(
            editor: model.editor,
            inputSource: TextInputSource.ime,
            customStylePhases: [LivePreviewPhase(model.composer, rendered)],
            componentBuilders: [
              MappedBuilder(TaskComponentBuilder(model.editor), rendered),
              MappedBuilder(const ParagraphComponentBuilder(), rendered),
              ...defaultComponentBuilders,
            ],
          ),
        ),
      ),
    );
    debugPrint('initial: ${shownTexts(tester).toList()}');
    expect(shownTexts(tester), containsAll(['bread fresh', 'see shop now']));

    await tapAtRaw(tester, '1', 7); // raw "see [s|hop]..."? offset 7 = 'o'
    debugPrint('caret line 1: ${shownTexts(tester).toList()} sel=${model.composer.selection}');
    expect(shownTexts(tester), containsAll(['bread fresh', 'see [shop](https://x.y) now']));

    await tester.typeImeText('X');
    debugPrint('typed: ${model.text}');
    expect(model.text, '- [ ] bread **fresh**\n- [ ] see [shXop](https://x.y) now');

    await tapAtRaw(tester, '0', 11);
    debugPrint('caret line 0: ${shownTexts(tester).toList()} sel=${model.composer.selection}');
    expect(shownTexts(tester), containsAll(['bread **fresh**', 'see shXop now']));
  });
}
