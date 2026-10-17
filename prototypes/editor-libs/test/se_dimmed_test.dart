import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proto/se_adapter.dart';
import 'package:proto/se_dimmed.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

void main() {
  testWidgets('dimmed marks: styled display, unchanged text and writes', (tester) async {
    final model = SeChecklist('- [ ] bread **fresh** today');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: model.editor,
          inputSource: TextInputSource.ime,
          customStylePhases: [DimmedMarksPhase()],
          componentBuilders: [TaskComponentBuilder(model.editor), ...defaultComponentBuilders],
        ),
      ),
    ));
    final span = tester
        .widgetList<RichText>(find.byWidgetPredicate((w) => w is RichText))
        .map((t) => t.text)
        .firstWhere((s) => s.toPlainText().contains('fresh'));
    final styles = <String>[];
    span.visitChildren((s) {
      if (s is TextSpan && s.text != null) {
        styles.add('${s.text}:${s.style?.fontWeight == FontWeight.bold ? 'B' : ''}${s.style?.color == const Color(0xFF9E9E9E) ? 'dim' : ''}');
      }
      return true;
    });
    debugPrint(styles.join(' | '));
    await tester.placeCaretInParagraph('0', 10); // inside "fr|esh"
    await tester.typeImeText('X');
    expect(model.text, '- [ ] bread **frXesh** today');
  });
}
