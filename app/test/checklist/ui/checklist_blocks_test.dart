import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/checklist/ui/checklist_blocks.dart';

void main() {
  /// Each block as `item: <raw>` or `text: <markdown>`.
  List<String> describe(String text) => [
    for (final block in blocksOf(Checklist.parse(text).lines))
      switch (block) {
        ItemBlock(:final first) => 'item: ${first.raw}',
        TextBlock(:final markdown) => 'text: $markdown',
      },
  ];

  test('groups the lines between items into one text block', () {
    expect(describe('# T\n\nintro\n- [ ] a\n\n- [ ] b\nnote\n```\nx\n```'), [
      'text: # T\n\nintro',
      'item: - [ ] a',
      'item: - [ ] b',
      'text: note\n```\nx\n```',
    ]);
  });
}
