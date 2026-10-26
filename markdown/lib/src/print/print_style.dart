/// The style a printed block writes in: its source's where it has one,
/// else the document's, else the standard style.
library;

import '../common/most_used.dart';
import '../doc/doc_nodes.dart';
import '../tree/blocks.dart';
import '../tree/document_style.dart';
import '../tree/inlines.dart';
import 'spans.dart';

/// The delimiters a text read from [source] (`null` for a new text)
/// writes its spans with, in a document of [document] style.
SpanStyle spanStyleOf(Block? source, DocumentStyle document) {
  final inlines = switch (source) {
    TextLeaf(:final text) => inlinesWithin(text.inlines).toList(),
    _ => const <Inline>[],
  };
  String used<T extends ContainerInline>(String fallback) =>
      mostUsed(inlines.whereType<T>().map((node) => node.open)) ?? fallback;
  return (
    emphasis: used<EmphasisInline>(document.emphasis),
    strong: used<StrongInline>(document.strong),
    strike: used<StrikeInline>(document.strike),
  );
}

/// How a new hard break in a text read from [source] is written: as its
/// hard breaks most are, else `\`.
String hardBreakOf(Block? source) => switch (source) {
  TextLeaf(:final text) => switch (mostUsed(
    inlinesWithin(text.inlines)
        .whereType<HardBreakInline>()
        .map((node) => node.style.name),
  )) {
    'spaces' => '  ',
    _ => r'\',
  },
  _ => r'\',
};

/// The bullet [list]'s items are written with: its first item's as read,
/// else the document's.
String bulletOf(ListNode list, DocumentStyle document) => switch (list.source) {
  ListBlock(:final items) => items.first.marker.bullet ?? document.bullet,
  _ => document.bullet,
};

/// The delimiter after [list]'s numbers: its first item's as read, else
/// `.`.
String delimiterOf(ListNode list) => switch (list.source) {
  ListBlock(:final items) => items.first.marker.delimiter ?? '.',
  _ => '.',
};
