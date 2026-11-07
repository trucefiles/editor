import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The calendar views bar's [title], which ends in the arrow of its
/// picker.
Finder viewsTitle(String title) => find.byWidgetPredicate(
  (widget) =>
      widget is RichText &&
      // The arrow stands as one placeholder.
      widget.text.toPlainText() == '$title\uFFFC',
);
