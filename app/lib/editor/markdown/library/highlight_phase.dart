import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show Highlight, HighlightSpan;

/// [highlight] as an attribution of library text.
@immutable
final class HighlightAttribution implements Attribution {
  const HighlightAttribution(this.highlight);

  final Highlight highlight;

  @override
  String get id => 'highlight:$highlight';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is HighlightAttribution && other.highlight == highlight;

  @override
  int get hashCode => highlight.hashCode;
}

/// Gives each line's text its highlights ([highlightsOf] its node), as
/// attributions the stylesheet styles; the document's text stays plain.
///
/// The highlights change only with the lines, so only with a change of
/// the document, after which the library styles every node anew. Marked
/// dirty earlier, while the library's transaction still ends, it would
/// style nodes that are gone.
final class HighlightPhase extends SingleColumnLayoutStylePhase {
  HighlightPhase(this.highlightsOf);

  final List<HighlightSpan> Function(String nodeId) highlightsOf;

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) => SingleColumnLayoutViewModel(
    padding: viewModel.padding,
    componentViewModels: [
      for (final component in viewModel.componentViewModels)
        switch (component) {
          final TextComponentViewModel text => _highlighted(text),
          _ => component,
        },
    ],
  );

  SingleColumnLayoutComponentViewModel _highlighted(
    TextComponentViewModel component,
  ) {
    final text = AttributedText(component.text.toPlainText());
    for (final (:start, :end, :highlight) in highlightsOf(component.nodeId)) {
      if (end > start) {
        text.addAttribution(
          HighlightAttribution(highlight),
          SpanRange(start, end - 1),
        );
      }
    }
    return (component.copy() as TextComponentViewModel)..text = text;
  }
}
