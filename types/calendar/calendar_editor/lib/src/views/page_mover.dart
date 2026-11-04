/// Moves the views page by page to where the user asks. While a move is
/// under way, the next step counts from where that move goes, not from
/// the page shown midway, so quick taps on Next or Previous each count.
final class PageMover {
  PageMover({required this.pageOn, required this.animateTo});

  /// A day of the page [by] pages on from the one [from] is on, else
  /// from the page shown.
  final DateTime Function(int by, {DateTime? from}) pageOn;

  /// Moves the views to the page [date] is on; done when the move ends.
  final Future<void> Function(DateTime date) animateTo;

  /// Where the moves under way go, while there are any.
  DateTime? _target;
  int _moving = 0;

  /// One page on (back if [by] is negative).
  Future<void> step(int by) => to(pageOn(by, from: _target));

  /// To the page [date] is on, e.g. today.
  Future<void> to(DateTime date) async {
    _target = date;
    _moving++;
    try {
      await animateTo(date);
    } finally {
      if (--_moving == 0) _target = null;
    }
  }
}
