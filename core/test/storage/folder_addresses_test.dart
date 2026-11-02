import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test("a folder's own name is its last segment", () {
    expect(lastSegment(Uri.parse('file:///home/me/Notes/')), 'Notes');
    expect(lastSegment(Uri.parse('file:///')), 'file:///');
  });

  test('shows a folder on this device as a path', () {
    expect(shownAddress(Uri.parse('file:///home/me/Notes')), '/home/me/Notes');
    expect(shownAddress(Uri.parse('cloud://me/Notes')), 'cloud://me/Notes');
  });

  test('reads back only saved addresses of folders on this device', () {
    expect(savedFileAddress('file:///a'), Uri.parse('file:///a'));
    expect(savedFileAddress('cloud://me/a'), isNull);
  });

  test('tells a folder in a hidden folder', () {
    expect(liesInHidden(Uri.parse('file:///s/.stversions/old')), isTrue);
    expect(liesInHidden(Uri.parse('file:///s/.hidden')), isTrue);
    expect(liesInHidden(Uri.parse('file:///s/notes')), isFalse);
  });
}
