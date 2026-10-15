import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/ui/line_break_formatter.dart';

void main() {
  test('pasted line breaks become \\n', () {
    final formatted = lineBreakFormatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'a\r\nb\rc\nd',
        selection: TextSelection.collapsed(offset: 8),
      ),
    );

    expect(formatted.text, 'a\nb\nc\nd');
    expect(formatted.selection, const TextSelection.collapsed(offset: 7));
  });
}
