import 'package:flutter/material.dart';

import '../../editor/document_metrics.dart';
import '../../editor/document_text_styles.dart';
import '../../editor/library/editor_look.dart';

/// How a plain text looks while edited in [theme]: every line in the
/// document's body text, nothing styled.
EditorLook plainLook(ThemeData theme, {required DocumentMetrics metrics}) {
  final body = DocumentTextStyles.body(theme);
  return EditorLook(
    theme,
    metrics: metrics,
    textStyleOf: (_) => body,
    inlineTextStyler: (_, style) => style,
  );
}
