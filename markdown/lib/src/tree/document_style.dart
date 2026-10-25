import 'package:collection/collection.dart';

import 'blocks.dart';
import 'inlines.dart';

/// How a document writes what it holds, by what it uses most: new content
/// is written the same way. A document without any takes the defaults.
final class DocumentStyle {
  const DocumentStyle({
    this.emphasis = '*',
    this.strong = '**',
    this.strike = '~~',
    this.bullet = '-',
  });

  /// The style [root] uses most.
  factory DocumentStyle.of(RootBlock root) {
    final inlines = root.leaves
        .whereType<TextLeaf>()
        .expand((leaf) => _withInner(leaf.text.inlines))
        .toList();
    String mostUsed<T extends ContainerInline>(String fallback) =>
        _mostUsed(inlines.whereType<T>().map((node) => node.open), fallback);
    return DocumentStyle(
      emphasis: mostUsed<EmphasisInline>('*'),
      strong: mostUsed<StrongInline>('**'),
      strike: mostUsed<StrikeInline>('~~'),
      bullet: _mostUsed(
        _items(root).map((item) => item.marker.bullet).nonNulls,
        '-',
      ),
    );
  }

  /// `*` or `_`.
  final String emphasis;

  /// `**` or `__`.
  final String strong;

  /// `~~` or `~`.
  final String strike;

  /// `-`, `*` or `+`.
  final String bullet;
}

Iterable<Inline> _withInner(List<Inline> inlines) => inlines.expand(
  (inline) => [
    inline,
    if (inline is ContainerInline) ..._withInner(inline.children),
  ],
);

Iterable<ItemBlock> _items(Block block) => switch (block) {
  ItemBlock(:final children) => [block, ...children.expand(_items)],
  ContainerBlock(:final children) => children.expand(_items),
  LeafBlock() => const [],
};

String _mostUsed(Iterable<String> used, String fallback) =>
    maxBy(
      groupBy(used, (value) => value).entries,
      (entry) => entry.value.length,
    )?.key ??
    fallback;
