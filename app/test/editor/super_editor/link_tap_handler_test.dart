import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_editor/editor/super_editor/link_tap_handler.dart';

/// When a tap opens a link while editing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const position = DocumentPosition(
    nodeId: 'a',
    nodePosition: TextNodePosition(offset: 0),
  );

  test('a plain tap opens one on a line the caret is not in', () {
    expect(editingTapOpens(position, tapOpens: true, caretNode: 'b'), isTrue);
    expect(editingTapOpens(position, tapOpens: true, caretNode: null), isTrue);
  });

  test('a plain tap on the caret line places the caret instead', () {
    expect(editingTapOpens(position, tapOpens: true, caretNode: 'a'), isFalse);
  });

  test('without plain taps, a tap opens none', () {
    expect(editingTapOpens(position, tapOpens: false, caretNode: 'b'), isFalse);
  });
}
