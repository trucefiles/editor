import 'package:flutter/painting.dart';
import 'package:super_editor/super_editor.dart';

const dimAttribution = NamedAttribution('dim');

/// PROTOTYPE: Markdown marks shown dimmed, the text between them styled;
/// the text itself is unchanged, so offsets need no mapping.
class DimmedMarksPhase extends SingleColumnLayoutStylePhase {
  static final _bold = RegExp(r'(\*\*)(.+?)(\*\*)');

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final vm in viewModel.componentViewModels)
          if (vm is TextComponentViewModel) _style(vm) else vm,
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _style(SingleColumnLayoutComponentViewModel vm) {
    final copy = vm.copy();
    final t = copy as TextComponentViewModel;
    final text = AttributedText(t.text.toPlainText());
    for (final m in _bold.allMatches(text.toPlainText())) {
      text.addAttribution(dimAttribution, SpanRange(m.start, m.start + 1));
      text.addAttribution(boldAttribution, SpanRange(m.start + 2, m.end - 3));
      text.addAttribution(dimAttribution, SpanRange(m.end - 2, m.end - 1));
    }
    final base = t.textStyleBuilder;
    t.text = text;
    t.textStyleBuilder = (attributions) {
      final style = base(attributions);
      return attributions.contains(dimAttribution)
          ? style.copyWith(color: const Color(0xFF9E9E9E))
          : style;
    };
    return copy;
  }
}
