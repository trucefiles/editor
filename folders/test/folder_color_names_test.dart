import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/folder_color_names.dart';

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
