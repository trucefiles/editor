import 'package:truce_markdown/truce_markdown.dart' show NodeId;

/// Where a dragged item goes: next to [item], below or above it; the
/// gap that opens there is [height] high, as the dragged row.
typedef LineGap = ({NodeId item, bool below, double height});

/// Where a drag over a `LineDropZone` is, from lift to settle.
sealed class LineDragState {
  const LineDragState();

  /// The item being dragged; `null` while none is.
  NodeId? get lifted;

  /// The gap open for the dragged item; `null` while none is.
  LineGap? get gap;
}

/// No item is dragged.
final class NoDrag extends LineDragState {
  const NoDrag();

  @override
  NodeId? get lifted => null;

  @override
  LineGap? get gap => null;
}

/// [item] is dragged, or its copy glides back to its row; [gap] is open
/// where it would go, `null` while it would stay where it is.
final class Lifted extends LineDragState {
  const Lifted(this.item, {this.gap});

  final NodeId item;

  @override
  final LineGap? gap;

  @override
  NodeId get lifted => item;
}

/// [item] was dropped next to another row: its old place closes while
/// its copy glides into [gap].
final class Landing extends LineDragState {
  const Landing(this.item, this.gap);

  final NodeId item;

  @override
  final LineGap gap;

  @override
  NodeId get lifted => item;
}
