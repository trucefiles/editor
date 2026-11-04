import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/follow_the_leader.dart';

/// [child] right below the [caret] (above it where there is no room),
/// [gap] away, kept inside the widget [area] keys; hidden while the
/// caret is outside that area (e.g. scrolled away).
class CaretFollower extends StatelessWidget {
  const CaretFollower({
    required this.caret,
    required this.area,
    required this.gap,
    required this.child,
    super.key,
  });

  final LeaderLink caret;
  final GlobalKey area;
  final double gap;
  final Widget child;

  /// Whether the caret shows within [area].
  bool get _caretInArea {
    final box = area.currentContext?.findRenderObject();
    final (at, size) = (caret.offset, caret.leaderSize);
    if (box is! RenderBox || !box.hasSize || at == null || size == null) {
      return false;
    }
    final shown = box.localToGlobal(Offset.zero) & box.size;
    return shown.contains(at) && shown.contains(at + Offset(0, size.height));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: caret,
    builder: (context, _) => _caretInArea
        ? Follower.withAligner(
            link: caret,
            aligner: PreferredPositionAligner.bottom(gap: gap),
            boundary: WidgetFollowerBoundary(boundaryKey: area),
            child: child,
          )
        : const SizedBox.shrink(),
  );
}
