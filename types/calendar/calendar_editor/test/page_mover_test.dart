import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/src/views/calendar_views.dart';
import 'package:truce_calendar_editor/src/views/page_mover.dart';

/// The day view's pages.
final _days = switch (configurationsFor(
  firstDayOfWeek: DateTime.monday,
  now: () => DateTime(2026, 11, 3),
)[CalendarViewKind.day]) {
  MultiDayViewConfiguration(:final pageIndexCalculator) => pageIndexCalculator,
  _ => throw StateError('no day view'),
};

void main() {
  /// A mover over the day pages showing [shown], whose slides end only
  /// when [slides] complete; each slide and jump goes to [moves].
  ({PageMover mover, List<String> moves, List<Completer<void>> slides}) moverOn(
    DateTime shown,
  ) {
    final moves = <String>[];
    final slides = <Completer<void>>[];
    final mover = PageMover(
      pages: () => _days,
      shown: () => shown,
      animateTo: (date) {
        moves.add('slide ${date.month}/${date.day}');
        return (slides..add(Completer())).last.future;
      },
      jumpTo: (date) => moves.add('jump ${date.year}/${date.month}'),
    );
    return (mover: mover, moves: moves, slides: slides);
  }

  test('the next or previous page slides in; a farther one shows at '
      'once', () {
    final (:mover, :moves, slides: _) = moverOn(DateTime(2026, 11, 3));
    unawaited(mover.to(DateTime(2026, 11, 4)));
    unawaited(mover.to(DateTime(1950, 6)));
    expect(moves, ['slide 11/4', 'jump 1950/6']);
  });

  test('a far move during a slide: the next step counts from there', () {
    final (:mover, :moves, :slides) = moverOn(DateTime(2026, 11, 3));
    unawaited(mover.step(1));
    unawaited(mover.to(DateTime(1950, 6, 10)));
    unawaited(mover.step(1));
    expect(moves, ['slide 11/4', 'jump 1950/6', 'slide 6/11']);
    for (final slide in slides) {
      slide.complete();
    }
  });
}
