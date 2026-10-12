import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/checklist/checklist_preview.dart';

void main() {
  test('shows open items with their level', () {
    expect(
      checklistPreview('# T\n- [ ] a\n- [x] b\n  - [ ] c\n- [ ] d\n  - [ ] e'),
      '☐ a\n☐ d\n  ☐ e',
    );
  });

  test('is null without checkbox items', () {
    expect(checklistPreview('# T\ntext'), isNull);
  });
}
