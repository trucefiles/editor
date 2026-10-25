import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/redraft.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/write/draft.dart';
import 'package:truce_core/src/note/write/note_writer.dart';

String _redrafted(
  String text,
  Map<BlockId, List<Draft>> Function(NoteTree tree) replaced,
) {
  final tree = NoteTree.read(text);
  return written(tree, redrafted(tree, replaced(tree))).text;
}

void main() {
  test('a block with an entry becomes its drafts, the rest stays', () {
    expect(
      _redrafted('a\n\nb\n\nc', (tree) => {tree.root.children[1].id: const []}),
      'a\n\nc',
    );
  });

  test('a block moves by one entry placing it and one removing it', () {
    expect(
      _redrafted('> a\n\nb', (tree) {
        final [quote as QuoteBlock, b] = tree.root.children;
        return {
          b.id: const [],
          quote.id: [
            QuoteDraft.of(quote, [
              KeptDraft(quote.children.single),
              KeptDraft(b),
            ]),
          ],
        };
      }),
      '> a\n>\n> b',
    );
  });

  test('a block listed again in its own container stays removed', () {
    expect(
      _redrafted('a\n\nb', (tree) {
        final [a, b] = tree.root.children;
        return {
          b.id: const [],
          tree.root.id: [KeptDraft(a), KeptDraft(b)],
        };
      }),
      'a',
    );
  });

  test('a list or quote left without blocks goes', () {
    expect(
      _redrafted(
        '- a\n\n> b\n\nc',
        (tree) => {for (final leaf in tree.leaves.take(2)) leaf.id: const []},
      ),
      'c',
    );
  });
}
