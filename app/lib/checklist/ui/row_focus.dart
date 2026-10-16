import 'package:flutter/widgets.dart';

/// Focus nodes of a checklist's text rows, so arrow keys can move the
/// cursor from row to row.
///
/// Rows are keyed by line id. Call [show] on every build with the rows in
/// screen order; nodes of rows no longer shown are disposed after that
/// frame.
final class RowFocus {
  final _nodes = <Object, FocusNode>{};
  final _carets = <Object, int>{};
  List<Object> _order = const [];

  /// The node of the row [key].
  FocusNode of(Object key) => _nodes.putIfAbsent(key, FocusNode.new);

  /// Sets the rows shown, top to bottom.
  void show(List<Object> keys) {
    _order = keys;
    final gone = _nodes.keys.where((key) => !keys.contains(key)).toList();
    if (gone.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final key in gone) {
        if (!_order.contains(key)) {
          _nodes.remove(key)?.dispose();
          _carets.remove(key);
        }
      }
    });
  }

  /// The row [step] rows from row [key] (−1 up, +1 down); `null` past
  /// the first or last row.
  Object? near(Object key, int step) {
    final target = _order.indexOf(key) + step;
    return target < 0 || target >= _order.length ? null : _order[target];
  }

  /// Moves the focus from row [key] by [step] rows (−1 up, +1 down).
  /// Stays put at the first and last row.
  void move(Object key, int step) {
    final target = _order.indexOf(key) + step;
    if (target < 0 || target >= _order.length) return;
    of(_order[target]).requestFocus();
  }

  /// Focuses row [key] once it is built, e.g. a row just added. With
  /// [caret], the row puts the cursor there as it is next built (see
  /// [takeCaret]), e.g. where two rows were joined.
  void focusLater(Object key, {int? caret}) {
    if (caret != null) _carets[key] = caret;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nodes[key]?.requestFocus(),
    );
  }

  /// Where [focusLater] wants the cursor of row [key], once; `null` if
  /// nowhere.
  int? takeCaret(Object key) => _carets.remove(key);

  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
    _carets.clear();
  }
}
