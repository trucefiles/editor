import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/checklist/ui/checklist_blocks.dart';

void main() {
  /// Each block as `item: <raw>` or `text: <markdown>`.
  List<String> describe(String text) => [
    for (final block in blocksOf(MarkdownLines.parse(text).lines))
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

  group('splitAtItems', () {
    /// Number of blocks in head, body and tail.
    List<int> split(String text) {
      final (:head, :body, :tail) = splitAtItems(
        blocksOf(MarkdownLines.parse(text).lines),
      );
      return [head.length, body.length, tail.length];
    }

    test('puts the text above, between and below the items apart', () {
      expect(split('# T\n- [ ] a\nmid\n- [ ] b\n\nend'), [1, 3, 1]);
    });

    test('keeps indented text right below the last item with it', () {
      expect(split('- [ ] a\n  details'), [0, 2, 0]);
      expect(split('- [ ] a\n\n  quote'), [0, 1, 1]);
    });

    test('without items, all text is above', () {
      expect(split('# T\ntext'), [1, 0, 0]);
      expect(split(''), [0, 0, 0]);
    });
  });
}
