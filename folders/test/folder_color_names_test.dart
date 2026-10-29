import 'package:test/test.dart';
import 'package:truce_folders/truce_folders.dart';

void main() {
  const offered = ['teal', 'pink', 'green'];

  test('picks the first color no folder has', () {
    expect(nextFolderColor([], offered), 'teal');
    expect(nextFolderColor(['teal', 'green'], offered), 'pink');
  });

  test('repeats the colors in order once all are used', () {
    expect(nextFolderColor(offered, offered), 'teal');
    expect(nextFolderColor([...offered, 'teal'], offered), 'teal');
  });
}
