import 'package:test/test.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

void main() {
  test('counts lines as written, a break at the end starting none', () {
    expect(textCounts('').lines, 0);
    expect(textCounts('one').lines, 1);
    expect(textCounts('one\n').lines, 1);
    expect(textCounts('one\r\ntwo\rthree\n\nfive').lines, 5);
  });

  test('counts words between spaces and breaks, markup included', () {
    expect(textCounts('').words, 0);
    expect(textCounts('  \n ').words, 0);
    expect(textCounts('# Shopping list\n- [ ] milk,  eggs\n').words, 8);
  });
}
