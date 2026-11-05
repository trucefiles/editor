import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// Scrolls the document whose layout [layout] keys so that node [id]
/// shows whole: its bottom first, then its top, which wins for a node
/// taller than the view. Where it shows whole already, nothing moves.
void showWhole(GlobalKey layout, String id) {
  final component = switch (layout.currentState) {
    final DocumentLayout layout => layout.getComponentByNodeId(id),
    _ => null,
  };
  if (component == null || !component.mounted) return;
  for (final policy in const [
    ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    ScrollPositionAlignmentPolicy.keepVisibleAtStart,
  ]) {
    unawaited(
      Scrollable.ensureVisible(component.context, alignmentPolicy: policy),
    );
  }
}
