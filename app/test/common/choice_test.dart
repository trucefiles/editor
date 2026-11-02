import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/choice.dart';

final _choice = NotifierProvider<Choice<String>, String?>(Choice<String>.new);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  Choice<String> choice() => container.read(_choice.notifier);

  test('reveal drops another pick', () {
    choice()
      ..choose('notes')
      ..reveal('calendars');

    expect(container.read(_choice), isNull);
  });

  test('reveal keeps the same pick, and no pick', () {
    choice()
      ..choose('notes')
      ..reveal('notes');
    expect(container.read(_choice), 'notes');

    choice()
      ..choose(null)
      ..reveal('notes');
    expect(container.read(_choice), isNull);
  });
}
