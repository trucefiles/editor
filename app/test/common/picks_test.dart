import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/picks.dart';

final _picks = NotifierProvider<Picks<String>, Set<String>>(Picks<String>.new);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Picks<String> picks() => container.read(_picks.notifier);
  Set<String> picked() => container.read(_picks);

  test('toggle picks and unpicks, several at once', () {
    picks()
      ..toggle('notes')
      ..toggle('calendars');
    expect(picked(), {'notes', 'calendars'});

    picks().toggle('notes');
    expect(picked(), {'calendars'});
  });

  test('drop unpicks', () {
    picks()
      ..toggle('notes')
      ..drop('notes')
      ..drop('other');

    expect(picked(), isEmpty);
  });

  test('reveal adds to other picks, and leaves none picked as it is', () {
    picks().reveal('notes');
    expect(picked(), isEmpty);

    picks()
      ..toggle('calendars')
      ..reveal('notes')
      ..reveal('notes');
    expect(picked(), {'calendars', 'notes'});
  });
}
