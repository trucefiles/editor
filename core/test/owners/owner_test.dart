import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

/// Counts its inputs; outputs each count.
TransitionOwner<int, int, (), int> _counter() => TransitionOwner(
  0,
  (),
  (state, work, input) =>
      (state: state + input, work: work, outputs: [state + input]),
);

void main() {
  test('handles an input before send returns', () {
    final owner = _counter()..send(2);
    expect(owner.state, 2);
  });

  test('keeps its work to itself, from one input to the next', () {
    // Shows the sum of its inputs; works with the last one.
    final owner = TransitionOwner<int, int, int, int>(
      0,
      0,
      (state, last, input) =>
          (state: state + input, work: input, outputs: [last]),
    );
    final lasts = <int>[];
    owner.outputs.listen(lasts.add);
    owner
      ..send(2)
      ..send(5);
    expect(owner.state, 7);
    expect(lasts, [0, 2]);
  });

  test('outputs follow their input, after its state is set', () {
    final owner = _counter();
    final seen = <(int, int)>[];
    owner.outputs.listen((output) => seen.add((output, owner.state)));
    owner
      ..send(1)
      ..send(2);
    expect(seen, [(1, 1), (3, 3)]);
  });

  test('an input sent while one is handled waits for it', () {
    final owner = _counter();
    final seen = <int>[];
    owner.outputs.listen((output) {
      seen.add(output);
      if (output == 1) {
        owner.send(10);
        // Not handled yet: the first input's outputs come first.
        expect(owner.state, 1);
      }
    });
    owner.send(1);
    expect(seen, [1, 11]);
    expect(owner.state, 11);
  });
}
