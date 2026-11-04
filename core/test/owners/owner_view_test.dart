import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test(
    'wraps inputs and shows state and events through its mappings',
    () async {
      final inner = SimpleOwner<int, int, int>(0, (input, out) async {
        out
          ..state = out.state + input
          ..emit(input);
      });
      final view = OwnerView<String, bool, String, int, int, int>(
        inner,
        input: int.parse,
        state: (sum) => sum > 2,
        event: (added) => 'added $added',
      );
      final changes = <bool>[];
      final events = <String>[];
      view.changes.listen(changes.add);
      view.events.listen(events.add);

      view
        ..send('1')
        ..send('1')
        ..send('1');
      await view.close();

      expect(view.state, isTrue);
      expect(changes, [false, true], reason: 'not again while it stays');
      expect(events, ['added 1', 'added 1', 'added 1']);
    },
  );

  test('leaves out the events it maps to nothing', () async {
    final inner = SimpleOwner<int, int, int>(0, (input, out) async {
      out.emit(input);
    });
    final view = OwnerView<int, int, String, int, int, int>(
      inner,
      input: (input) => input,
      state: (state) => state,
      event: (event) => event.isEven ? 'even $event' : null,
    );
    final events = <String>[];
    view.events.listen(events.add);

    view
      ..send(1)
      ..send(2)
      ..send(3);
    await view.close();

    expect(events, ['even 2']);
  });
}
