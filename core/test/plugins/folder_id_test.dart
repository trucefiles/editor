import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('parses ids of lowercase letters and digits only', () {
    expect(FolderId.parse('local', 'a1b2'), const FolderId('local', 'a1b2'));
    expect(FolderId.parse('local', '../x'), isNull);
    expect(FolderId.parse('Local', 'a1'), isNull);
    expect(FolderId.parse('local', ''), isNull);
  });

  test('a new plugin folder id is a valid part, and new each time', () {
    final ids = {for (var i = 0; i < 20; i++) newPluginFolderId()};

    expect(ids, hasLength(20));
    expect(ids.every(FolderId.isPart), isTrue);
  });
}
