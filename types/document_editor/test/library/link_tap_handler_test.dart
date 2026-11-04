import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_document_editor/truce_document_editor.dart';

/// When a tap opens a link while editing.
void main() {
  const position = DocumentPosition(
    nodeId: 'a',
    nodePosition: TextNodePosition(offset: 0),
  );

  testWidgets('a plain tap opens none: it places the caret', (tester) async {
    expect(editingTapOpens(position), isFalse);
  });

  for (final key in [
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.metaLeft,
  ]) {
    testWidgets('a tap with ${key.keyLabel} held opens one', (tester) async {
      await tester.sendKeyDownEvent(key);
      expect(editingTapOpens(position), isTrue);
      await tester.sendKeyUpEvent(key);
    });
  }
}
