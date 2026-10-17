import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// PROTOTYPE: inline Markdown rendered with its markers hidden, plus the map
/// from rendered offsets back to raw offsets. Only `**bold**` and
/// `[text](url)` for the prototype.
class Rendered {
  Rendered(this.text, this.rawOffsets);

  final AttributedText text;

  /// rawOffsets[i] = raw offset of rendered offset i (length + 1 entries).
  final List<int> rawOffsets;

  int toRaw(int rendered) => rawOffsets[rendered.clamp(0, rawOffsets.length - 1)];

  int toRendered(int raw) {
    for (var i = 0; i < rawOffsets.length; i++) {
      if (rawOffsets[i] >= raw) return i;
    }
    return rawOffsets.length - 1;
  }

  static final _token = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]*)\)');

  factory Rendered.of(String raw) {
    final out = StringBuffer();
    final offsets = <int>[];
    final spans = <(int, int, Attribution)>[];
    var pos = 0;
    void copy(int from, int to) {
      for (var i = from; i < to; i++) {
        offsets.add(i);
        out.write(raw[i]);
      }
    }

    for (final m in _token.allMatches(raw)) {
      copy(pos, m.start);
      final start = out.length;
      if (m.group(1) != null) {
        final inner = m.start + 2;
        copy(inner, inner + m.group(1)!.length);
        spans.add((start, out.length - 1, boldAttribution));
      } else {
        final inner = m.start + 1;
        copy(inner, inner + m.group(2)!.length);
        spans.add((start, out.length - 1, LinkAttribution(m.group(3)!)));
      }
      pos = m.end;
    }
    copy(pos, raw.length);
    offsets.add(raw.length);
    final text = AttributedText(out.toString());
    for (final (s, e, a) in spans) {
      if (e >= s) text.addAttribution(a, SpanRange(s, e));
    }
    return Rendered(text, offsets);
  }
}

/// Shows nodes outside the selection rendered; the selected ones raw.
class LivePreviewPhase extends SingleColumnLayoutStylePhase {
  LivePreviewPhase(this._composer, this.rendered) {
    _composer.selectionNotifier.addListener(markDirty);
  }

  final DocumentComposer _composer;

  /// Rendered state per node id, for the components' offset mapping.
  final Map<String, Rendered> rendered;

  @override
  void dispose() {
    _composer.selectionNotifier.removeListener(markDirty);
    super.dispose();
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    rendered.clear();
    final selection = _composer.selection;
    final touched = selection == null
        ? <String>{}
        : document
              .getNodesInside(selection.base, selection.extent)
              .map((n) => n.id)
              .toSet();
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final vm in viewModel.componentViewModels)
          if (vm is TextComponentViewModel && !touched.contains(vm.nodeId))
            _render(vm)
          else
            vm,
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _render(
    SingleColumnLayoutComponentViewModel vm,
  ) {
    final copy = vm.copy();
    final text = copy as TextComponentViewModel;
    final r = Rendered.of(text.text.toPlainText());
    rendered[vm.nodeId] = r;
    text.text = r.text;
    return copy;
  }
}

/// Wraps a text component; maps rendered offsets to raw node positions
/// while the node is shown rendered.
class MappedComponent extends StatefulWidget {
  const MappedComponent({
    super.key,
    required this.nodeId,
    required this.rendered,
    required this.child,
  });

  final String nodeId;
  final Map<String, Rendered> rendered;
  final Widget Function(GlobalKey key) child;

  @override
  State<MappedComponent> createState() => _MappedComponentState();
}

class _MappedComponentState extends State<MappedComponent>
    with ProxyDocumentComponent<MappedComponent>, ProxyTextComposable {
  final _childKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _childKey;

  @override
  TextComposable get childTextComposable =>
      _childKey.currentState as TextComposable;

  Rendered? get _r => widget.rendered[widget.nodeId];

  NodePosition _toRaw(NodePosition p) => switch ((_r, p)) {
    (final r?, TextNodePosition(:final offset, :final affinity)) =>
      TextNodePosition(offset: r.toRaw(offset), affinity: affinity),
    _ => p,
  };

  NodePosition _toRendered(NodePosition p) => switch ((_r, p)) {
    (final r?, TextNodePosition(:final offset, :final affinity)) =>
      TextNodePosition(offset: r.toRendered(offset), affinity: affinity),
    _ => p,
  };

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    final p = super.getPositionAtOffset(localOffset);
    return p == null ? null : _toRaw(p);
  }

  @override
  NodePosition getBeginningPositionNearX(double x) =>
      _toRaw(super.getBeginningPositionNearX(x));

  @override
  NodePosition getEndPositionNearX(double x) =>
      _toRaw(super.getEndPositionNearX(x));

  @override
  NodePosition getEndPosition() => _toRaw(super.getEndPosition());

  @override
  Offset getOffsetForPosition(NodePosition p) =>
      super.getOffsetForPosition(_toRendered(p));

  @override
  Rect getRectForPosition(NodePosition p) =>
      super.getRectForPosition(_toRendered(p));

  @override
  CaretGeometry getCaretForPosition(NodePosition p) =>
      super.getCaretForPosition(_toRendered(p));

  @override
  Widget build(BuildContext context) => widget.child(_childKey);
}

/// Paragraph and task builders that wrap their component in [MappedComponent].
class MappedBuilder implements ComponentBuilder {
  MappedBuilder(this.inner, this.rendered);

  final ComponentBuilder inner;
  final Map<String, Rendered> rendered;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => inner.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext context,
    SingleColumnLayoutComponentViewModel vm,
  ) {
    if (inner.createComponent(context, vm) == null) return null;
    return MappedComponent(
      key: context.componentKey,
      nodeId: vm.nodeId,
      rendered: rendered,
      child: (key) => inner.createComponent(
        SingleColumnDocumentComponentContext(
          context: context.context,
          componentKey: key,
        ),
        vm,
      )!,
    );
  }
}
