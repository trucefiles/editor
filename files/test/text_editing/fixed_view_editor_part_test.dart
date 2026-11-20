import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

void main() {
  test('switches between editing and reading, telling each change', () {
    final part = _Part(readOnly: true);
    var told = 0;
    part.changes.listen((_) => told++);
    expect(part.isEditing, isFalse);

    part.showReadOnly(readOnly: true);
    expect(told, 0, reason: 'no change');

    part.showReadOnly(readOnly: false);
    expect(part.isEditing, isTrue);
    expect(told, 1);
    part.dispose();
  });
}

final class _Part extends FixedViewEditorPart {
  _Part({required super.readOnly});

  @override
  PageEditor get editor => throw UnimplementedError();
}
