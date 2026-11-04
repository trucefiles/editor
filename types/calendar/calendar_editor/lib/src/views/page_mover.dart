import 'package:kalender/kalender.dart';

/// Moves the views page by page to where the user asks, by kalender's own
/// page numbers. While a move is under way, the next step counts from the
/// page that move goes to, not from the page shown midway (which kalender
/// rounds back), so quick taps on Next or Previous each count.
final class PageMover {
  PageMover({
    required this.pages,
    required this.shown,
    required this.animateTo,
  });

  /// The pages of the view shown now.
  final PageIndexCalculator Function() pages;

  /// A day of the page shown.
  final DateTime Function() shown;

  /// Moves the views to the page [date] is on; done when the move ends.
  final Future<void> Function(DateTime date) animateTo;

  /// The page the moves under way go to, while there are any.
  int? _target;
  int _moving = 0;

  /// One page on (back if [by] is negative), within the pages there are.
  Future<void> step(int by) {
    final pages = this.pages();
    final from = _target ?? pages.indexFromDate(shown(), null);
    final page = (from + by).clamp(0, pages.numberOfPages(null) - 1);
    final range = pages.rangeFromIndex(page, null);
    // Its middle: a month's first row starts in the month before.
    final day = range.start.add(range.end.difference(range.start) ~/ 2);
    return _move(page, day);
  }

  /// To the page [date] is on, e.g. today.
  Future<void> to(DateTime date) =>
      _move(pages().indexFromDate(date, null), date);

  Future<void> _move(int page, DateTime date) async {
    _target = page;
    _moving++;
    try {
      await animateTo(date);
    } finally {
      if (--_moving == 0) _target = null;
    }
  }
}
